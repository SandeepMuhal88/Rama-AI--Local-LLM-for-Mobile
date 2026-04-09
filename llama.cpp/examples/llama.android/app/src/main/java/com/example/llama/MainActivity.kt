package com.example.llama

import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.arm.aichat.AiChat
import com.arm.aichat.InferenceEngine
import com.arm.aichat.gguf.FileType
import com.arm.aichat.gguf.GgufMetadata
import com.arm.aichat.gguf.GgufMetadataReader
import com.arm.aichat.isModelLoaded
import com.arm.aichat.isUninterruptible
import com.google.android.material.button.MaterialButton
import com.google.android.material.floatingactionbutton.FloatingActionButton
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.Locale
import java.util.UUID

private const val FILE_EXTENSION_GGUF = ".gguf"

class MainActivity : AppCompatActivity() {

    private lateinit var statusTv: TextView
    private lateinit var modelNameTv: TextView
    private lateinit var ggufTv: TextView
    private lateinit var messagesRv: RecyclerView
    private lateinit var userInputEt: EditText
    private lateinit var userActionFab: FloatingActionButton
    private lateinit var importModelButton: MaterialButton
    private lateinit var resetChatButton: MaterialButton
    private lateinit var stopButton: MaterialButton

    private lateinit var engine: InferenceEngine
    private lateinit var preferences: AssistantPreferences

    private val metadataReader = GgufMetadataReader.create()
    private var generationJob: Job? = null
    private var stopRequested = false
    private var temporaryStatus: String? = null

    private var currentModelFile: File? = null
    private var currentModelDisplayName: String? = null
    private var currentMetadataSummary: String? = null

    private val messages = mutableListOf<Message>()
    private val lastAssistantMsg = StringBuilder()
    private val messageAdapter = MessageAdapter(messages)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)

        preferences = AssistantPreferences(applicationContext)
        bindViews()
        setupRecyclerView()

        engine = AiChat.getInferenceEngine(applicationContext)
        observeEngineState()
        restoreSavedModelIfAvailable()
    }

    private fun bindViews() {
        statusTv = findViewById(R.id.status)
        modelNameTv = findViewById(R.id.model_name)
        ggufTv = findViewById(R.id.gguf)
        messagesRv = findViewById(R.id.messages)
        userInputEt = findViewById(R.id.user_input)
        userActionFab = findViewById(R.id.fab)
        importModelButton = findViewById(R.id.import_model)
        resetChatButton = findViewById(R.id.reset_chat)
        stopButton = findViewById(R.id.stop_generation)

        importModelButton.setOnClickListener {
            getContent.launch(arrayOf("*/*"))
        }
        resetChatButton.setOnClickListener {
            resetConversation()
        }
        stopButton.setOnClickListener {
            stopRequested = true
            engine.cancelGeneration()
        }
        userActionFab.setOnClickListener {
            handleUserInput()
        }
    }

    private fun setupRecyclerView() {
        messagesRv.layoutManager = LinearLayoutManager(this).apply {
            stackFromEnd = true
        }
        messagesRv.adapter = messageAdapter
    }

    private fun observeEngineState() {
        lifecycleScope.launch {
            engine.state.collect { state ->
                renderState(state)
            }
        }
    }

    private fun restoreSavedModelIfAvailable() {
        lifecycleScope.launch {
            val savedModel = preferences.loadImportedModel() ?: return@launch
            val localModelFile = File(ensureModelsDirectory(), savedModel.fileName)
            if (!localModelFile.exists()) {
                preferences.clearImportedModel()
                return@launch
            }

            try {
                setTemporaryStatus(getString(R.string.status_restoring_model))
                val metadata = readMetadata(localModelFile)
                loadAssistantModel(
                    displayName = savedModel.displayName,
                    modelFile = localModelFile,
                    metadata = metadata,
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restore cached model", e)
                preferences.clearImportedModel()
                currentModelFile = null
                currentModelDisplayName = null
                currentMetadataSummary = null
                showToast(getString(R.string.restore_failed))
            } finally {
                setTemporaryStatus(null)
            }
        }
    }

    private val getContent = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let { handleSelectedModel(it) }
    }

    private fun handleSelectedModel(uri: Uri) {
        lifecycleScope.launch {
            try {
                setTemporaryStatus(getString(R.string.status_importing_model))
                val metadata = readMetadata(uri)
                val modelFile = copyImportedModel(uri, metadata)
                val displayName = metadata.displayName().ifBlank {
                    modelFile.nameWithoutExtension
                }

                loadAssistantModel(
                    displayName = displayName,
                    modelFile = modelFile,
                    metadata = metadata,
                )
                showToast(getString(R.string.model_ready_toast, displayName))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to import model from $uri", e)
                showToast(e.message ?: getString(R.string.model_import_failed))
            } finally {
                setTemporaryStatus(null)
            }
        }
    }

    private suspend fun loadAssistantModel(
        displayName: String,
        modelFile: File,
        metadata: GgufMetadata,
    ) {
        awaitEngineStartup()
        prepareEngineForModelLoad()

        engine.loadModel(modelFile.path)
        engine.setSystemPrompt(DEFAULT_SYSTEM_PROMPT)

        currentModelFile = modelFile
        currentModelDisplayName = displayName
        currentMetadataSummary = metadata.summary(modelFile)
        preferences.saveImportedModel(modelFile.name, displayName)

        resetConversationUi()
        addAssistantMessage(getString(R.string.assistant_ready_message, displayName))
    }

    private suspend fun awaitEngineStartup() {
        engine.state.first { state ->
            state !is InferenceEngine.State.Uninitialized &&
                state !is InferenceEngine.State.Initializing
        }
    }

    private fun resetConversation() {
        val modelFile = currentModelFile ?: return
        val displayName = currentModelDisplayName ?: modelFile.nameWithoutExtension

        lifecycleScope.launch {
            try {
                setTemporaryStatus(getString(R.string.status_resetting_chat))
                val metadata = readMetadata(modelFile)
                loadAssistantModel(
                    displayName = displayName,
                    modelFile = modelFile,
                    metadata = metadata,
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to reset conversation", e)
                showToast(e.message ?: getString(R.string.reset_failed))
            } finally {
                setTemporaryStatus(null)
            }
        }
    }

    private suspend fun prepareEngineForModelLoad() {
        when (engine.state.value) {
            is InferenceEngine.State.Initialized -> Unit
            is InferenceEngine.State.ModelReady,
            is InferenceEngine.State.Error -> engine.cleanUp()

            else -> throw IllegalStateException(getString(R.string.engine_busy))
        }
    }

    private fun handleUserInput() {
        val userMsg = userInputEt.text.toString().trim()
        if (userMsg.isEmpty()) {
            showToast(getString(R.string.empty_message))
            return
        }

        stopRequested = false
        userInputEt.text = null

        addMessage(Message(UUID.randomUUID().toString(), userMsg, true))
        lastAssistantMsg.clear()
        addMessage(Message(UUID.randomUUID().toString(), "", false))

        generationJob?.cancel()
        generationJob = lifecycleScope.launch {
            try {
                engine.sendUserPrompt(
                    message = userMsg,
                    predictLength = ASSISTANT_PREDICT_LENGTH,
                ).onCompletion {
                    finalizeAssistantMessage()
                }.collect { token ->
                    val lastIndex = messages.lastIndex
                    if (lastIndex < 0 || messages[lastIndex].isUser) {
                        return@collect
                    }

                    messages[lastIndex] = messages[lastIndex].copy(
                        content = lastAssistantMsg.append(token).toString()
                    )
                    messageAdapter.notifyItemChanged(lastIndex)
                    scrollToBottom()
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Failed to generate a response", e)
                showToast(e.message ?: getString(R.string.generation_failed))
            }
        }
    }

    private fun finalizeAssistantMessage() {
        val lastIndex = messages.lastIndex
        if (lastIndex < 0 || messages[lastIndex].isUser) {
            stopRequested = false
            return
        }

        if (messages[lastIndex].content.isBlank()) {
            val fallback = if (stopRequested) {
                getString(R.string.generation_stopped_message)
            } else {
                getString(R.string.empty_response_message)
            }
            messages[lastIndex] = messages[lastIndex].copy(content = fallback)
            messageAdapter.notifyItemChanged(lastIndex)
        }
        stopRequested = false
        scrollToBottom()
    }

    private fun addAssistantMessage(content: String) {
        addMessage(Message(UUID.randomUUID().toString(), content, false))
    }

    private fun addMessage(message: Message) {
        messages.add(message)
        messageAdapter.notifyItemInserted(messages.lastIndex)
        scrollToBottom()
    }

    private fun resetConversationUi() {
        generationJob?.cancel()
        stopRequested = false
        lastAssistantMsg.clear()
        messages.clear()
        messageAdapter.notifyDataSetChanged()
        scrollToBottom()
    }

    private fun scrollToBottom() {
        if (messages.isNotEmpty()) {
            messagesRv.scrollToPosition(messages.lastIndex)
        }
    }

    private suspend fun readMetadata(uri: Uri): GgufMetadata =
        withContext(Dispatchers.IO) {
            contentResolver.openInputStream(uri)?.buffered()?.use { input ->
                metadataReader.readStructuredMetadata(input)
            } ?: error(getString(R.string.cannot_open_model))
        }

    private suspend fun readMetadata(file: File): GgufMetadata =
        withContext(Dispatchers.IO) {
            file.inputStream().buffered().use { input ->
                metadataReader.readStructuredMetadata(input)
            }
        }

    private suspend fun copyImportedModel(uri: Uri, metadata: GgufMetadata): File =
        withContext(Dispatchers.IO) {
            val suggestedFileName = uri.displayName()
                ?.sanitizeModelFileName()
                ?: metadata.filename()
            contentResolver.openInputStream(uri)?.use { input ->
                ensureModelFile(suggestedFileName, input)
            } ?: error(getString(R.string.cannot_open_model))
        }

    private suspend fun ensureModelFile(modelName: String, input: InputStream): File =
        withContext(Dispatchers.IO) {
            File(ensureModelsDirectory(), modelName).also { file ->
                if (!file.exists()) {
                    FileOutputStream(file).use { output -> input.copyTo(output) }
                }
            }
        }

    private fun ensureModelsDirectory() =
        File(filesDir, DIRECTORY_MODELS).also {
            if (it.exists() && !it.isDirectory) {
                it.delete()
            }
            if (!it.exists()) {
                it.mkdir()
            }
        }

    private fun renderState(state: InferenceEngine.State) {
        val statusText = temporaryStatus ?: when (state) {
            InferenceEngine.State.Uninitialized,
            InferenceEngine.State.Initializing -> getString(R.string.status_initializing)

            InferenceEngine.State.Initialized -> {
                if (currentModelFile == null) {
                    getString(R.string.status_pick_model)
                } else {
                    getString(R.string.status_model_cached)
                }
            }

            InferenceEngine.State.LoadingModel -> getString(R.string.status_loading_model)
            InferenceEngine.State.UnloadingModel -> getString(R.string.status_unloading_model)
            InferenceEngine.State.ModelReady -> getString(R.string.status_model_ready)
            InferenceEngine.State.Benchmarking -> getString(R.string.status_benchmarking)
            InferenceEngine.State.ProcessingSystemPrompt -> getString(R.string.status_system_prompt)
            InferenceEngine.State.ProcessingUserPrompt -> getString(R.string.status_processing_prompt)
            InferenceEngine.State.Generating -> getString(R.string.status_generating)
            is InferenceEngine.State.Error -> getString(
                R.string.status_error,
                state.exception.message ?: state.exception.javaClass.simpleName
            )
        }

        statusTv.text = statusText
        modelNameTv.text = currentModelDisplayName?.let {
            getString(R.string.model_name_format, it)
        } ?: getString(R.string.model_name_empty)
        ggufTv.text = currentMetadataSummary ?: getString(R.string.metadata_placeholder)

        val isBusy = temporaryStatus != null ||
            state.isUninterruptible ||
            state is InferenceEngine.State.Generating
        importModelButton.isEnabled = !isBusy
        resetChatButton.isEnabled = temporaryStatus == null &&
            currentModelFile != null &&
            state !is InferenceEngine.State.Initializing &&
            state !is InferenceEngine.State.LoadingModel &&
            state !is InferenceEngine.State.UnloadingModel &&
            state !is InferenceEngine.State.Generating &&
            state !is InferenceEngine.State.Benchmarking &&
            state !is InferenceEngine.State.ProcessingSystemPrompt &&
            state !is InferenceEngine.State.ProcessingUserPrompt
        stopButton.isEnabled = state is InferenceEngine.State.ProcessingUserPrompt ||
            state is InferenceEngine.State.Generating

        val canSend = temporaryStatus == null &&
            state is InferenceEngine.State.ModelReady &&
            state.isModelLoaded
        userInputEt.isEnabled = canSend
        userActionFab.isEnabled = canSend
        userInputEt.hint = if (canSend) {
            getString(R.string.prompt_ready_hint)
        } else {
            getString(R.string.prompt_disabled_hint)
        }
    }

    private fun setTemporaryStatus(status: String?) {
        temporaryStatus = status
        renderState(engine.state.value)
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    override fun onStop() {
        generationJob?.cancel()
        if (::engine.isInitialized) {
            engine.cancelGeneration()
        }
        super.onStop()
    }

    override fun onDestroy() {
        if (::engine.isInitialized) {
            engine.destroy()
        }
        super.onDestroy()
    }

    private fun Uri.displayName(): String? {
        contentResolver.query(this, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (columnIndex >= 0) {
                        return cursor.getString(columnIndex)
                    }
                }
            }
        return null
    }

    companion object {
        private val TAG = MainActivity::class.java.simpleName

        private const val DIRECTORY_MODELS = "models"
        private const val ASSISTANT_PREDICT_LENGTH = 256
        private val DEFAULT_SYSTEM_PROMPT = """
            You are a helpful offline AI assistant running fully on the user's device.
            Give practical, honest answers.
            Keep replies clear and concise unless the user asks for more detail.
            If you are unsure, say so.
            Never pretend to have internet access, live updates, or remote tools.
        """.trimIndent()
    }
}

private fun GgufMetadata.filename(): String {
    val baseName = basic.nameLabel
        ?.takeIf { it.isNotBlank() }
        ?: basic.name
            ?.takeIf { it.isNotBlank() }
            ?.let { name ->
                basic.sizeLabel
                    ?.takeIf { it.isNotBlank() }
                    ?.let { size -> "$name-$size" }
                    ?: name
            }
        ?: architecture?.architecture
            ?.takeIf { it.isNotBlank() }
            ?.let { architectureName -> "$architectureName-${System.currentTimeMillis()}" }
        ?: "model-${System.currentTimeMillis()}"

    return baseName.sanitizeModelFileName()
}

private fun GgufMetadata.displayName(): String =
    basic.nameLabel
        ?.takeIf { it.isNotBlank() }
        ?: basic.name
            ?.takeIf { it.isNotBlank() }
            ?.let { name ->
                basic.sizeLabel
                    ?.takeIf { it.isNotBlank() }
                    ?.let { size -> "$name ($size)" }
                    ?: name
            }
        ?: architecture?.architecture
            ?.takeIf { it.isNotBlank() }
            ?.replaceFirstChar { char ->
                if (char.isLowerCase()) {
                    char.titlecase(Locale.getDefault())
                } else {
                    char.toString()
                }
            }
        ?: "GGUF Model"

private fun GgufMetadata.summary(modelFile: File): String = buildList {
    add(displayName())
    architecture?.architecture?.let { add("Architecture: $it") }
    dimensions?.contextLength?.let { add("Context: $it tokens") }
    architecture?.fileType?.let { fileType ->
        add("Quantization: ${FileType.fromCode(fileType).label}")
    }
    dimensions?.blockCount?.let { add("Layers: $it") }
    add("Local size: ${modelFile.length().toReadableFileSize()}")
}.joinToString(separator = "\n")

private fun String.sanitizeModelFileName(): String {
    val trimmed = trim().ifEmpty { "model" }
    val withoutExtension = trimmed.removeSuffix(FILE_EXTENSION_GGUF)
    val safeName = withoutExtension.replace(Regex("[^A-Za-z0-9._-]+"), "-")
        .trim('-')
        .ifEmpty { "model" }
    return "$safeName$FILE_EXTENSION_GGUF"
}

private fun Long.toReadableFileSize(): String {
    if (this <= 0L) {
        return "0 B"
    }

    val units = arrayOf("B", "KB", "MB", "GB", "TB")
    var size = toDouble()
    var unitIndex = 0
    while (size >= 1024.0 && unitIndex < units.lastIndex) {
        size /= 1024.0
        unitIndex++
    }
    return String.format(Locale.US, "%.1f %s", size, units[unitIndex])
}
