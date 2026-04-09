package com.example.llama

import android.content.Context

class AssistantPreferences(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveImportedModel(fileName: String, displayName: String) {
        prefs.edit()
            .putString(KEY_MODEL_FILE_NAME, fileName)
            .putString(KEY_MODEL_DISPLAY_NAME, displayName)
            .apply()
    }

    fun loadImportedModel(): SavedModel? {
        val fileName = prefs.getString(KEY_MODEL_FILE_NAME, null) ?: return null
        val displayName = prefs.getString(KEY_MODEL_DISPLAY_NAME, fileName) ?: fileName
        return SavedModel(fileName = fileName, displayName = displayName)
    }

    fun clearImportedModel() {
        prefs.edit()
            .remove(KEY_MODEL_FILE_NAME)
            .remove(KEY_MODEL_DISPLAY_NAME)
            .apply()
    }

    data class SavedModel(
        val fileName: String,
        val displayName: String,
    )

    private companion object {
        private const val PREFS_NAME = "offline_assistant_prefs"
        private const val KEY_MODEL_FILE_NAME = "model_file_name"
        private const val KEY_MODEL_DISPLAY_NAME = "model_display_name"
    }
}
