# RAMA AI — Complete Architecture & Technical Reference

> **Version:** 1.2.0+3  
> **Platform:** Android (arm64-v8a)  
> **Paradigm:** 100 % offline — zero cloud API calls  
> **App ID:** com.example.rama_ai  
> **Last Updated:** April 2026

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Full Folder Structure](#3-full-folder-structure)
4. [Technology Stack](#4-technology-stack)
5. [Flutter Layer — Screen by Screen](#5-flutter-layer--screen-by-screen)
6. [Native Layer — llama.cpp FFI](#6-native-layer--llamacpp-ffi)
7. [Storage Layer — SQLite + SharedPreferences](#7-storage-layer--sqlite--sharedprefs)
8. [Data Flow — End-to-End Inference](#8-data-flow--end-to-end-inference)
9. [Chat History & Conversation Memory](#9-chat-history--conversation-memory)
10. [Model Manager & Download System](#10-model-manager--download-system)
11. [Theme System](#11-theme-system)
12. [Android Configuration](#12-android-configuration)
13. [Dependencies & Versions](#13-dependencies--versions)
14. [Conventions & Code Style](#14-conventions--code-style)
15. [Known Limitations & Tuning Knobs](#15-known-limitations--tuning-knobs)
16. [Build & Run Commands](#16-build--run-commands)

---

## 1. Project Overview

**RAMA AI** is a production-ready, fully offline AI assistant for Android.  
It runs large language models (LLMs) locally on the device using **llama.cpp** compiled as a native `.so` library, called from Flutter via **Dart FFI**. No internet is required for inference.

### Core Design Goals

| Goal | Implementation |
|---|---|
| Feel like Claude AI | Sidebar history panel, clean bubbles, minimal UI |
| 100% offline inference | llama.cpp via FFI — no API calls |
| Non-blocking UI | Dart Isolate (`compute()`) for all inference |
| Persistent chat history | SQLite via sqflite |
| Multiple model support | Download (Dio) + file browser import |
| Modern design | Dark/light mode, accent colors, micro-animations |

---

## 2. High-Level Architecture

```
+-------------------------------------------------------------+
|                      Flutter UI Layer                       |
|                                                             |
|  SplashScreen -> EntryPoint -> ProfileSetup / ChatScreen    |
|  ChatScreen <-> Sidebar (History Panel)                     |
|  ChatScreen <-> ModelManagerScreen                          |
+------------------+------------------------------------------+
                   |  Dart FFI (ffi package, dart:ffi)
+------------------v------------------------------------------+
|               Native Layer (C++17 / NDK 28)                 |
|                                                             |
|  libllama_lib.so  <-  wrapper.cpp  <-  llama.cpp            |
|  run_model_path(model_path, prompt) -> char* (heap)         |
+------------------+------------------------------------------+
                   |  reads GGUF from Android filesystem
+------------------v------------------------------------------+
|                      Storage Layer                          |
|                                                             |
|  SQLite (sqflite)   ->  conversations, messages tables      |
|  SharedPreferences  ->  theme, accent, active model path    |
|  Android filesystem ->  .gguf model files                   |
+-------------------------------------------------------------+
```

### Key Design Decisions

| Decision | Reason |
|---|---|
| Dart Isolate `compute()` for inference | Prevents UI thread from blocking during 1-30+ second inference |
| SQLite for chat history | Structured queries, foreign keys, cascading delete support |
| SharedPreferences for settings | Simple K/V — no SQL needed for theme/model path |
| Dio for downloads | Streaming progress callbacks; `CancelToken` cancel support |
| FFI (not Platform Channels) | Lower overhead; direct C-string passing without method channel serialization |
| CPU-only inference (`n_gpu_layers = 0`) | Universally safe across all Android GPU vendors |
| Context window = 512 tokens | Minimises KV-cache RAM; phones with less than 4 GB free can OOM with larger contexts |
| Greedy sampler | Fastest sampling; no temperature/top-p computation overhead |

---

## 3. Full Folder Structure

```
RAMA-APP/
|-- docs/
|   |-- Update.Md           <- Latest update changelog
|   +-- ARCHITECTURE.md     <- THIS FILE (full technical reference)
|
+-- rama_ai/                <- Flutter project root
    |-- pubspec.yaml
    |-- pubspec.lock
    |-- analysis_options.yaml
    |
    |-- android/
    |   +-- app/
    |       |-- build.gradle.kts   <- NDK version, ABI filter, compileSdk=36
    |       +-- src/main/
    |           |-- AndroidManifest.xml  <- permissions, largeHeap, no Impeller
    |           |-- kotlin/              <- MainActivity (Flutter embedding v2)
    |           +-- cpp/
    |               |-- CMakeLists.txt       <- CMake build: llama.cpp + wrapper
    |               |-- wrapper.cpp          <- FFI entry point + inference pipeline
    |               +-- llama.cpp/           <- llama.cpp source (git submodule)
    |                   |-- llama.h
    |                   |-- llama.cpp
    |                   +-- ...
    |
    |-- assets/
    |   +-- icon/
    |       +-- app_icon.png    <- Adaptive launcher icon
    |
    +-- lib/
        |-- main.dart           <- App entry, theme init, launches SplashScreen
        |
        |-- core/
        |   +-- app_theme.dart  <- AppTheme ChangeNotifier, RamaColors tokens,
        |                          kAccentPresets, global 'appTheme' singleton
        |
        |-- models/
        |   +-- chat_message.dart  <- ChatMessage class, MessageRole enum
        |
        |-- screens/
        |   |-- splash_screen.dart        <- RAMA AI animated launch screen
        |   |-- entry_point.dart          <- First-launch gate (profile check)
        |   |-- profile_setup_screen.dart <- Name, avatar, accent color picker
        |   |-- chat_screen.dart          <- Main chat UI + sidebar drawer
        |   +-- model_manager_screen.dart <- Download, import & switch models
        |
        |-- services/
        |   +-- llm_service.dart  <- Dart FFI wrapper around libllama_lib.so,
        |                            model directory helpers (listModels, modelsDir)
        |
        |-- storage/
        |   +-- chat_storage.dart <- SQLite service: Conversation, StoredMessage,
        |                            ChatStorage static class
        |
        |-- utils/
        |   +-- response_cleaner.dart <- Strip control tokens from LLM output
        |
        +-- widgets/
            +-- shared_widgets.dart   <- LogoBadge, RamaIconBtn, ActionCard,
                                         SuggestionChip, SendButton, MessageBubble
```

---

## 4. Technology Stack

### Flutter / Dart Packages

| Package | Version | Purpose |
|---|---|---|
| `flutter` SDK | `^3.11.4` | Core UI framework |
| `ffi` | `^2.1.0` | Low-level C function calling |
| `path_provider` | `^2.1.2` | Android external/document storage paths |
| `dio` | `^5.4.0` | HTTP client — model downloads with progress |
| `permission_handler` | `^11.3.1` | Runtime storage permission requests |
| `shared_preferences` | `^2.3.2` | Lightweight K/V persistence (theme, model) |
| `file_picker` | `^8.1.2` | Native OS file browser to pick `.gguf` files |
| `sqflite` | `^2.3.3` | SQLite ORM — chat history storage |
| `path` | `^1.9.0` | Cross-platform path joining (used in chat_storage) |
| `intl` | `^0.19.0` | Internationalisation / date formatting |

### Native / Android

| Technology | Version | Role |
|---|---|---|
| llama.cpp | latest (submodule) | Core GGUF inference engine |
| C++17 | — | Wrapper language standard |
| Android NDK | 28.2.13676358 | Native compilation toolchain |
| CMake | 3.10+ | Build system that compiles `libllama_lib.so` |
| `android/log.h` | Android API | Logcat with `LOGI` / `LOGE` macros |

### Android Project

| Config | Value |
|---|---|
| Application ID | `com.example.rama_ai` |
| `compileSdk` | 36 |
| `minSdk` | 21 (Android 5.0+) |
| `targetSdk` | Flutter default |
| ABI filter | `arm64-v8a` only (64-bit ARM) |
| `largeHeap` | `true` — allows extra RAM headroom for LLM |
| Impeller / Vulkan | **disabled** — frees GPU memory budget for model layers |
| Java / Kotlin JVM target | 17 |

---

## 5. Flutter Layer — Screen by Screen

### 5.1 `main.dart` — App Entry Point

**Responsibilities:**
- Async init: loads `SharedPreferences` for `theme_dark` and `accent_idx`
- Initialises global `AppTheme` singleton (`appTheme`)
- Sets `SystemChrome` status/nav bar colours
- Runs `RamaApp` → `MaterialApp` → `SplashScreen`

`RamaApp` is a `StatefulWidget` that registers a listener on `appTheme` and calls `setState()` on theme changes, causing the entire material theme to update live.

---

### 5.2 `splash_screen.dart` — Animated Launch

**Total duration:** ~2.3 seconds

| Phase | Start delay | Duration | Widget | Curve |
|---|---|---|---|---|
| Logo scale + fade | 200ms | 700ms | `ScaleTransition` + `FadeTransition` | `elasticOut` |
| "RAMA AI" slide + fade | 400ms | 600ms | `SlideTransition` (from y+0.3) + `FadeTransition` | `easeOutCubic` |
| Tagline + dots fade | 300ms | 500ms | `FadeTransition` | `easeOut` |
| Navigate to EntryPoint | 900ms hold | 600ms crossfade | `PageRouteBuilder` + `FadeTransition` | — |

Background uses two `RadialGradient` circles in the current accent colour (top-left + bottom-right) for ambient depth without images.

`_PulseDots` — inner `StatefulWidget` with its own `AnimationController` that creates a wave-style 3-dot pulsing animation using phase offset math.

---

### 5.3 `entry_point.dart` — First-Launch Gate

```
EntryPoint.initState()
  -> _check()
       SharedPreferences: user_name
         empty  -> ProfileSetupScreen   (first launch)
         filled -> ChatScreen           (returning user)
```

Shows `CircularProgressIndicator` during async check. No splash animation (splash already handled before this).

---

### 5.4 `profile_setup_screen.dart` — User Onboarding / Settings

**What it persists to SharedPreferences:**

| Key | Type | Value |
|---|---|---|
| `user_name` | `String` | The user's display name |
| `user_avatar` | `int` | Index into `_avatarEmojis` list (0-7) |
| `accent_idx` | `int` | Index into `kAccentPresets` colour list (0-7) |

**UI elements:**
- 8 emoji avatar tiles in animated `Wrap` grid
- Name `TextField` with real-time validation
- 8 colour swatch circles for accent pick
- Save button with gradient, disabled at 45% opacity when name is empty

**Navigation:** On first save → `pushReplacement(ChatScreen)`. On edit → `pop()`.

**Animation:** FadeTransition + SlideTransition entrance (700ms, easeOutCubic).

---

### 5.5 `chat_screen.dart` — Core Chat UI

This is the most complex screen in the app.

#### Internal State

```dart
// Messages
final List<ChatMessage> _messages   // in-memory list of current session
bool _thinking                      // true while inference runs
String? _activeModelPath            // absolute path to loaded .gguf

// History
List<Conversation> _conversations   // all SQLite conversations
int? _currentConvId                 // currently loaded conversation ID
bool _historyLoading                // true while loading sidebar list

// Sidebar
bool _sidebarOpen                   // open/closed
AnimationController _sidebarCtrl    // 280ms slide animation
Animation<double>   _sidebarAnim    // easeOutCubic

// Profile
String _userName
int    _userAvatar

// Thinking dots
AnimationController _dotCtrl        // repeating 900ms
Animation<double>   _dotAnim        // 0.0 -> 1.0 repeating
```

#### Lifecycle Init Chain

```
_init()
  |- _requestPermissions()    Permission.storage + manageExternalStorage
  |- _loadProfile()           SharedPreferences -> _userName, _userAvatar
  |- _loadSavedModel()        SharedPreferences active_model_path + File.existsSync()
  |- _refreshModels()         LLMService.listModels() -> auto-select first if none
  +- _loadConversations()     ChatStorage.listConversations() -> _conversations
```

#### Send Message Flow

```
_send()
  1. Validate: text not empty AND not currently thinking
  2. If no model: add error message, return
  3. If _currentConvId == null:
       ChatStorage.createConversation(title: first 40 chars of text)
  4. Append ChatMessage(user) to _messages; set _thinking = true
  5. ChatStorage.insertMessage(userMsg) [async, non-blocking]
  6. ChatStorage.lastMessages(_currentConvId!, 8) -> List<StoredMessage>
  7. _buildContextPrompt(history, text) -> multi-turn formatted string
  8. compute(runInferenceIsolate, [modelPath, prompt]) -> Dart Isolate
  9. On result:
       Append ChatMessage(ai) to _messages; _thinking = false
       ChatStorage.insertMessage(aiMsg) [async]
       If title was empty/default: ChatStorage.updateTitle()
       _loadConversations() -> refresh sidebar
```

#### Sidebar Behaviour

- Hamburger button (`Icons.menu_rounded`) in AppBar toggles sidebar
- Open: `AnimationController.forward()` + `setState(_sidebarOpen = true)`
- Close: `AnimationController.reverse()` + `setState(_sidebarOpen = false)` in `.then()`
- Scrim: `FadeTransition` with `GestureDetector` overlay — tap scrim to close
- Slide panel: `SlideTransition` from `Offset(-1, 0)` → `Offset.zero`
- Width: `clamp(240, 320)` — responsive

#### Conversation Tile UI

- Active conversation: accent-tinted background + accent border
- Date label: time (`HH:MM`) if today, else `DD/MM` if older
- Inline delete icon → `_confirmDelete(conv)` → `AlertDialog` → `ChatStorage.deleteConversation()`

#### Thinking Animation

Three dots with wave-phase offset formula:
```dart
final phase   = ((_dotAnim.value * 3) - i) % 3;
final opacity = phase < 1 ? phase : (phase < 2 ? 1.0 : 3.0 - phase);
```
This creates a rolling left-to-right brightness wave.

---

### 5.6 `model_manager_screen.dart` — Model Manager

#### Preset Catalogue (`kAvailableModels`)

| # | Name | Params | Size | HuggingFace URL |
|---|---|---|---|---|
| 1 | TinyLlama 1.1B Chat | 1.1B | 0.67 GB | TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF |
| 2 | Phi-2 2.7B | 2.7B | 1.79 GB | TheBloke/phi-2-GGUF |
| 3 | Gemma 2B Instruct | 2B | 1.35 GB | google/gemma-2b-it-GGUF |
| 4 | Phi-3 Mini 4K Instruct | 3.8B | 2.39 GB | microsoft/Phi-3-mini-4k-instruct-gguf |

#### Download State Machine

```dart
class _DownloadState {
  bool         active   = false;   // download running
  double       progress = 0.0;     // 0.0 - 1.0
  String       status   = '';      // "450 / 1792 MB"
  CancelToken? token;              // Dio cancel token
}
// Map<String filename, _DownloadState>  keyed by model filename
```

**Download sequence:**
1. Check file already exists → snack if yes
2. `setState` → UI shows progress bar + Cancel button
3. `Dio().download(url, destPath, onReceiveProgress: ...)` streaming
4. `onReceiveProgress`: compute MB string, update `progress` → `setState`
5. On success: `_loadAll()`, auto-select model if none active
6. On `DioExceptionType.cancel`: delete partial file, orange snack
7. On error: red snack with message
8. `finally`: `setState` reset `_DownloadState` to idle

#### Import (Browse) Flow

1. `FilePicker.platform.pickFiles(type: FileType.any)`
2. Validate `.gguf` extension
3. `LLMService.modelSavePath(filename)` → destination path in models dir
4. If not already there: show `Dialog(CircularProgressIndicator)` → `File.copy()`
5. `Navigator.of(context, rootNavigator: true).pop()` to dismiss dialog
6. `_loadAll()` to refresh local model list

#### Catalogue Card UI

Each card shows:
- Coloured icon + name + params/size + badge pill
- Description text
- Progress bar (only when `ds.active == true`)
- MB counter string
- Action button: `Download` (filled, gradient) / `Cancel` (outline, red) / `Use This Model` (outline) / `Active` badge

---

### 5.7 Shared Widgets (`shared_widgets.dart`)

#### `LogoBadge`

Gradient rounded square (topLeft → bottomRight in accent colour) with `Icons.auto_awesome_rounded`.  
Used in: AppBar, EmptyState, ThinkingBar, MessageBubble (AI avatar), Sidebar header.

#### `RamaIconBtn`

Bordered square icon button with `Tooltip`. Used for all AppBar action buttons.

#### `ActionCard`

Full-width gradient card (icon + title + subtitle + chevron). Used in empty state when no model is loaded.

#### `SuggestionChip`

Full-width bordered row with lightbulb icon and northeast arrow. Used on the empty state for prompt suggestions.

#### `SendButton`

`AnimatedContainer` that transitions between:
- **Enabled:** gradient fill, accent glow shadow, arrow-up icon
- **Thinking:** same gradient, hourglass icon
- **Disabled:** card colour, faded icon, no shadow

#### `MessageBubble`

**Entrance:** `FadeTransition` + `SlideTransition(0, 0.06 → 0)` (320ms easeOut).

| Role | Alignment | Background | Avatar | Border |
|---|---|---|---|---|
| `user` | Right | Accent gradient | Emoji in accent-tinted square (right side) | None |
| `ai` | Left | Card color | LogoBadge (left side) | Thin card border |
| `error` | Left | Red-tinted dark/light | LogoBadge | Red border |

Footer: timestamp (`HH:MM`) + copy-to-clipboard button (2s "Copied!" state) for AI/error messages.

---

## 6. Native Layer — llama.cpp FFI

### Build Chain

```
android/app/build.gradle.kts
  externalNativeBuild { cmake { path = "src/main/cpp/CMakeLists.txt" } }
  ndk { abiFilters += ["arm64-v8a"] }

CMakeLists.txt
  cmake_minimum_required(VERSION 3.10)
  project(rama_ai)
  set(CMAKE_CXX_STANDARD 17)
  add_subdirectory(llama.cpp)          -> builds libllama.a (static)
  add_library(llama_lib SHARED wrapper.cpp)
  target_link_libraries(llama_lib llama log)

Output: libllama_lib.so (arm64-v8a)
        embedded in APK at lib/arm64-v8a/libllama_lib.so
```

### FFI Binding (`llm_service.dart`)

```dart
// One-time load (lazy, cached via static field)
static DynamicLibrary? _lib;
static _RunModelDart?  _runFn;

static void _ensureLoaded() {
  if (_lib != null) return;
  _lib  = DynamicLibrary.open('libllama_lib.so');
  _runFn = _lib!.lookupFunction<
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>),  // C types
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)   // Dart types
  >('run_model_path');
}

Future<String> run(String modelPath, String prompt) async {
  await Future<void>.delayed(Duration.zero);   // yield for UI refresh
  _ensureLoaded();
  final mpPtr     = modelPath.toNativeUtf8();
  final pPtr      = prompt.toNativeUtf8();
  final resultPtr = _runFn!(mpPtr, pPtr);
  final text      = resultPtr.toDartString();
  malloc.free(mpPtr);
  malloc.free(pPtr);
  // resultPtr.address is strdup'd in C — not freed (acceptable for per-call lifetime)
  return text.isEmpty ? '(No response generated)' : text;
}
```

### `wrapper.cpp` — C++ Inference Pipeline

```
run_model_path(const char* model_path, const char* prompt) -> const char*

Step 1: llama_model_default_params()
        mp.n_gpu_layers = 0    (CPU-only, safe everywhere)

Step 2: llama_model_load_from_file(model_path, mp)
        On failure: return strdup("Error: Could not load model...")

Step 3: llama_context_default_params()
        cp.n_ctx   = 512    (KV-cache rows)
        cp.n_batch = 128    (prompt decode chunk size)
        llama_init_from_model(model, cp)
        On failure: llama_model_free + return error string

Step 4: llama_tokenize(vocab, prompt, ...)
        Guard: n_tokens >= n_ctx - 4 -> error

Step 5: llama_batch_init(n_tokens)
        Fill: token, pos, n_seq_id, seq_id, logits[last]=true
        llama_decode(ctx, batch)   -> prefill (KV-cache warmed)
        llama_batch_free(batch)

Step 6: Generation loop (max 128 iterations):
        tok = llama_sampler_sample(greedy, ctx, -1)
        if tok == EOS or tok < 0: break
        llama_token_to_piece(vocab, tok, buf, ...) -> append to output
        llama_batch_init(1) -> feed tok back -> llama_decode -> pos++

Step 7: Cleanup
        llama_sampler_free, llama_free, llama_model_free

Step 8: return strdup(output.c_str())
```

#### Inference Parameters

| Parameter | Value | Impact |
|---|---|---|
| `n_gpu_layers` | 0 | CPU-only — no Vulkan/CUDA needed |
| `n_ctx` | 512 | Each row = RAM; 512 is safe on 3 GB phones |
| `n_batch` | 128 | Prefill chunk; smaller = less peak RAM |
| `max_gen` | 128 | Max output tokens before forced stop |
| Sampler | Greedy (top-1) | Deterministic, fastest; no T/top-p overhead |

### Response Cleaner (`utils/response_cleaner.dart`)

Strips control tokens left over in LLM output using `String.replaceAll(RegExp)`:

| Pattern stripped |
|---|
| `<\|end\|>` / `<\|assistant\|>` chain |
| `<\|user\|>` |
| `<\|system\|>` |
| `<\|im_end\|>` / `<\|im_start\|>` |
| `[INST]` / `[/INST]` (Llama-2 style) |
| `<<SYS>>` / `<</SYS>>` |

Applied in `runInferenceIsolate()` after FFI returns.

---

## 7. Storage Layer — SQLite + SharedPreferences

### SQLite Schema (`chat_storage.dart`)

```sql
-- Conversations (one per chat session)
CREATE TABLE conversations (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  title      TEXT    NOT NULL,
  created_at INTEGER NOT NULL,   -- Unix ms
  updated_at INTEGER NOT NULL    -- Unix ms, updated on every new message
);

-- Messages (many per conversation)
CREATE TABLE messages (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL,
  role            TEXT    NOT NULL,   -- 'user' | 'ai' | 'error'
  text            TEXT    NOT NULL,
  time            INTEGER NOT NULL,   -- Unix ms timestamp
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);
```

**Database file:** `rama_ai_chats.db` in `getDatabasesPath()` (Android: `/data/data/com.example.rama_ai/databases/`)

**Lazy singleton:** `static Database? _db` — opened once, reused.

### ChatStorage API

| Method | Description |
|---|---|
| `createConversation({title})` | Returns new conversation `id` |
| `updateTitle(id, title)` | Called after first AI reply to set real title |
| `touchConversation(id)` | Updates `updated_at` (called by `insertMessage`) |
| `listConversations()` | All conversations `ORDER BY updated_at DESC` |
| `deleteConversation(id)` | Cascades to delete all messages |
| `insertMessage(StoredMessage)` | Inserts + touches conversation |
| `loadMessages(convId)` | All messages `ORDER BY time ASC` |
| `lastMessages(convId, n)` | Last N messages (for context injection), returned oldest-first |

### SharedPreferences Keys

| Key | Type | Default | Used by |
|---|---|---|---|
| `theme_dark` | `bool` | `true` | main.dart, ChatScreen toggle |
| `accent_idx` | `int` | `0` | main.dart, ProfileSetupScreen |
| `user_name` | `String` | `''` | ProfileSetup, ChatScreen greeting |
| `user_avatar` | `int` | `0` | ProfileSetup, ChatScreen, sidebar |
| `active_model_path` | `String` | `null` | ChatScreen, LLMService |

### Model File Storage

```
getExternalStorageDirectory() ?? getApplicationDocumentsDirectory()
  +-- RAMA_AI/
      +-- models/
          |-- tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
          |-- phi-2.Q4_K_M.gguf
          |-- Phi-3-mini-4k-instruct-q4.gguf
          +-- gemma-2b-it-q4.gguf
```

`LLMService.modelsDir` creates this directory if it doesn't exist (`createSync(recursive: true)`).

---

## 8. Data Flow — End-to-End Inference

```
User types message + taps Send
        |
        v  (UI thread)
_send() validates, creates conversation if needed
        |
        v  async
ChatStorage.insertMessage(userMsg)   [SQLite write]
        |
        v
ChatStorage.lastMessages(convId, 8)  [SQLite read]
        |
        v
_buildContextPrompt(history, newText)
  ->  "User: msg1\nAssistant: reply1\n...User: current\nAssistant:"
        |
        v
compute(runInferenceIsolate, [modelPath, fullPrompt])
        |   [spawns Dart Isolate - separate thread]
        v
LLMService().run(modelPath, prompt)
        |
        v  [FFI call - blocks native thread]
DynamicLibrary.open('libllama_lib.so')
run_model_path(model_path, prompt)  [C++ / wrapper.cpp]
        |
        v
llama_model_load_from_file(path, params)   [reads GGUF from flash storage]
        |   (1-10s load time depending on model size)
        v
Tokenize -> Prefill (llama_decode) -> Generate loop (max 128 tokens greedy)
        |
        v
Return char* (heap strdup) -> Dart toDartString()
        |
        v  [back to UI thread via compute() callback]
cleanLLMResponse(raw)   [strip control tokens]
        |
        v
setState: add ChatMessage(ai, reply) to _messages
          _thinking = false
        |
        v
ChatStorage.insertMessage(aiMsg)    [SQLite write]
ChatStorage.updateTitle(convId, ...)
_loadConversations()                [refresh sidebar]
        |
        v
ListView rebuilds -> MessageBubble appears with fade+slide animation
```

---

## 9. Chat History & Conversation Memory

### History Storage

Every message sent/received is immediately written to SQLite.  
On app restart, `_loadConversations()` fetches all past sessions for the sidebar.  
Tapping a conversation calls `ChatStorage.loadMessages(id)` and restores messages to `_messages[]` with their original timestamps.

### Conversation Memory (Context Injection)

```dart
String _buildContextPrompt(List<StoredMessage> history, String currentInput) {
  // history = last 8 messages from ChatStorage.lastMessages(convId, 8)
  for (final msg in history) {
    if (msg.role == 'user') buf.write('User: ${msg.text}\n');
    if (msg.role == 'ai')   buf.write('Assistant: ${msg.text}\n');
  }
  buf.write('User: $currentInput\nAssistant:');
  return buf.toString();
}
```

This makes the model aware of the last ~4 turns (8 messages = 4 user + 4 AI).  
The combined prompt length is naturally bounded by `n_ctx = 512` in the native layer.

---

## 10. Model Manager & Download System

### Download Architecture

```
ModelManagerScreen._downloads
  Map<String filename, _DownloadState>
        |
        |  kAvailableModels.forEach -> init _DownloadState for each
        |
_downloadModel(ModelInfo info)
        |
        |-- Dio() singleton created per download
        |-- dio.download(url, destPath, cancelToken, onReceiveProgress)
        |   ds.progress = received / total     (0.0 - 1.0)
        |   ds.status   = "${mb} / ${totalMb} MB"
        |   setState() per progress tick
        |
        |   on complete: _loadAll() -> refresh local models
        |
        |   on cancel: delete partial file at destPath
        |
_cancelDownload(ModelInfo info)
        +-- _downloads[info.filename]!.token!.cancel('User cancelled')
```

### Import Architecture

```
_browseAndImport()
        |
FilePicker.platform.pickFiles(type: FileType.any)
        |
Validate: path.endsWith('.gguf')
        |
LLMService.modelSavePath(filename)   -> dest in RAMA_AI/models/
        |
if !destFile.exists:
  showDialog(CopyingDialog)          -> blocking spinner
  await srcFile.copy(destPath)
  Navigator.of(context, rootNavigator: true).pop()
        |
_loadAll() -> refresh
```

### Model File Detection

```dart
// LLMService.listModels()
dir.listSync()
   .whereType<File>()
   .where((f) => f.path.toLowerCase().endsWith('.gguf'))
   ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()))
```

Matching catalogue entries to local files:
```dart
// _matchLocal(ModelInfo info)
_localModels.firstWhere(
  (f) => f.path.split('/').last.toLowerCase() == info.filename.toLowerCase()
)
```

---

## 11. Theme System

### Color Tokens (`core/app_theme.dart`)

#### Dark Mode

| Token | Color | Usage |
|---|---|---|
| `darkBg` | `#080814` | Scaffold background |
| `darkSurface` | `#10101F` | AppBar, sidebar, input bar |
| `darkCard` | `#161628` | Message bubbles, cards |
| `darkBorder` | `#252540` | All borders |
| `darkText` | `#EAEAF8` | Primary text |
| `darkTextSub` | `#8888AA` | Secondary text, timestamps |
| `darkTextDim` | `#44445A` | Placeholder text, icons |
| `error` | `#E57373` | Error messages |

#### Light Mode

| Token | Color | Usage |
|---|---|---|
| `lightBg` | `#F4F4FB` | Scaffold background |
| `lightSurface` | `#FFFFFF` | AppBar, sidebar |
| `lightCard` | `#F0F0FA` | Cards, bubbles |
| `lightBorder` | `#DDDDF0` | All borders |
| `lightText` | `#1A1A2E` | Primary text |
| `lightTextSub` | `#6666AA` | Secondary text |
| `lightTextDim` | `#AAAAC` | Dim elements |

### Accent Presets (`kAccentPresets`)

| Index | Color | Hex |
|---|---|---|
| 0 (default) | Purple | `#7C6EF5` |
| 1 | Sky Blue | `#42A5F5` |
| 2 | Teal | `#26C6DA` |
| 3 | Green | `#66BB6A` |
| 4 | Amber | `#FFA726` |
| 5 | Red | `#EF5350` |
| 6 | Pink | `#EC407A` |
| 7 | Violet | `#AB47BC` |

### AppTheme ChangeNotifier

```dart
late AppTheme appTheme;   // global singleton - set in main()

class AppTheme extends ChangeNotifier {
  bool  _isDark;
  Color _accent;

  void toggle()           // dark <-> light; notifyListeners()
  void setAccent(Color c) // change accent; notifyListeners()
  ThemeData get themeData // MaterialApp ThemeData (Material 3)
}
```

All screens listen via:
```dart
appTheme.addListener(() { if (mounted) setState(() {}); });
```
And compute colors on every build via getters like:
```dart
Color get _bg => appTheme.isDark ? RamaColors.darkBg : RamaColors.lightBg;
```

---

## 12. Android Configuration

### `AndroidManifest.xml`

```xml
<!-- Model downloads -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- GGUF file access (legacy + Android 11+) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>

<!-- App config -->
android:largeHeap="true"              <- Extra memory for LLM
android:requestLegacyExternalStorage  <- Compat for older Androids

<!-- Performance - free GPU RAM for LLM layers -->
<meta-data name="io.flutter.embedding.android.EnableImpeller" value="false"/>
```

### `build.gradle.kts` Key Settings

```kotlin
compileSdk = 36
ndkVersion = "28.2.13676358"   // explicitly pinned for reproducibility

ndk {
  abiFilters += listOf("arm64-v8a")   // 64-bit ARM only
}

externalNativeBuild {
  cmake {
    path = file("src/main/cpp/CMakeLists.txt")
  }
}
```

---

## 13. Dependencies & Versions

### Runtime Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  ffi:                ^2.1.0
  path_provider:      ^2.1.2
  dio:                ^5.4.0
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.2
  file_picker:        ^8.1.2
  sqflite:            ^2.3.3
  path:               ^1.9.0
  intl:               ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints:          ^6.0.0
  flutter_launcher_icons: ^0.14.1
```

### Resolved Notable Versions (pubspec.lock)

| Package | Resolved |
|---|---|
| sqflite | 2.4.2 |
| sqflite_android | 2.4.2+3 |
| sqflite_common | 2.5.6 |
| sqflite_darwin | 2.4.2 |
| dio | 5.x |
| file_picker | 8.3.7 |
| permission_handler | 11.4.0 |

---

## 14. Conventions & Code Style

### File Naming

| Pattern | Example |
|---|---|
| `snake_case.dart` | `chat_screen.dart`, `llm_service.dart` |
| One class per file (mostly) | `chat_message.dart` has `ChatMessage` + `MessageRole` |
| Private helpers at bottom | `_PulseDots`, `_FilledBtn`, `_OutlineBtn`, `_SectionTitle` |

### Code Layout

Every Dart file follows this order:
1. Imports (dart:, package:, relative)
2. Top-level functions / `typedef`s
3. Public class (with `// ─── Section ─` dividers)
4. Private helper classes

### Divider Comments

```dart
// ─── Build ────────────────────────────────────────────────────────────────────
// ── Send ─────────────────────────────────────────────────────────────────────
```
Two dashes (`──`) for sub-sections, three (`───`) for major sections.

### Color Usage Pattern

Colors are never hardcoded in widgets. Always use theme getters:
```dart
Color get _bg     => appTheme.isDark ? RamaColors.darkBg      : RamaColors.lightBg;
Color get _surface => appTheme.isDark ? RamaColors.darkSurface : RamaColors.lightSurface;
// etc.
```

### Static vs Instance

- `LLMService` — instantiated per-isolate call (needed because `compute()` spawns a new Dart isolate)
- `ChatStorage` — fully static with a lazy singleton `_db`
- `AppTheme` — single global instance `appTheme` (set in `main()`)

### Navigation Pattern

All navigation uses `PageRouteBuilder` with custom transitions:
- Model Manager opens: `SlideTransition` from bottom (0, 1→0)
- Profile opens: `SlideTransition` from bottom (0, 1→0)
- Splash → EntryPoint: `FadeTransition`
- ProfileSetup → ChatScreen: `FadeTransition`

---

## 15. Known Limitations & Tuning Knobs

### Current Limitations

| Limitation | Detail |
|---|---|
| No streaming output | `compute()` returns only after full generation; UI sees full reply at once |
| Max 128 output tokens | `max_gen = 128` in wrapper.cpp — short replies only |
| Context window 512 | Large prompts or long conversations won't fit; gets truncated at native layer |
| iOS not supported | FFI `.so` is Android-only; iOS would need separate `.dylib` + XCFramework |
| Model loading every call | `llama_model_load_from_file` called on every `_send()` — slow for large models |
| Memory leak | `resultPtr` from `strdup()` not freed (acceptable for one-call lifetime) |

### Tuning Knobs (wrapper.cpp)

| Parameter | Location | Options |
|---|---|---|
| `n_ctx` | `wrapper.cpp:35` | 256 (minimal RAM), 512 (default), 1024 (needs 4+GB) |
| `n_batch` | `wrapper.cpp:36` | 64/128/256 — affects prefill speed |
| `max_gen` | `wrapper.cpp:100` | 64 (fast/short), 128 (default), 256 (slow/long) |
| `n_gpu_layers` | `wrapper.cpp:23` | 0 (CPU), higher = GPU layers (Adreno/Mali experimental) |
| Sampler type | `wrapper.cpp:99` | `greedy`, `top-k`, `top-p/mirostat` alternatives |

### Tuning Knobs (Dart)

| Parameter | Location | Effect |
|---|---|---|
| Context messages | `chat_screen.dart:_send()` | `lastMessages(convId, 8)` — change 8 |
| Suggestion chips | `chat_screen.dart` | `_kSuggestions` list |
| Accent presets | `core/app_theme.dart` | `kAccentPresets` list |

---

## 16. Build & Run Commands

### Development

```bash
# Install all dependencies
flutter pub get

# Static analysis (must be clean)
flutter analyze --no-fatal-infos

# Run on connected Android device (debug)
flutter run

# Run with verbose native logs
flutter run --verbose
```

### Production Build

```bash
# APK (sideload)
flutter build apk --release

# Split APKs per ABI (smaller download)
flutter build apk --split-per-abi --release

# App Bundle (Play Store)
flutter build appbundle --release
```

### Native Logs (Logcat)

```bash
# Filter to RAMA AI native tag only
adb logcat -s RamaAI

# Full Flutter + native logs
adb logcat | grep -E "(flutter|RamaAI|llama)"
```

### Launcher Icon Regeneration

```bash
flutter pub run flutter_launcher_icons
```

### Clean Build

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## Appendix A — Inference Time Estimates

| Model | Size | Estimatedd Load Time | ~Tokens/sec (arm64, 4 cores) |
|---|---|---|---|
| TinyLlama 1.1B Q4_K_M | 0.67 GB | 2-5s | 10-20 tok/s |
| Phi-2 2.7B Q4_K_M | 1.79 GB | 5-12s | 4-8 tok/s |
| Gemma 2B Q4 | 1.35 GB | 4-8s | 6-12 tok/s |
| Phi-3 Mini 4K Q4 | 2.39 GB | 8-18s | 3-6 tok/s |

> All estimates are for mid-range Android (Snapdragon 778G). High-end (SD 8 Gen 2+) will be 1.5-2x faster.

---

## Appendix B — File Size / Lines of Code

| File | Lines | Purpose |
|---|---|---|
| `model_manager_screen.dart` | ~680 | Largest — download UI + catalogue |
| `chat_screen.dart` | ~580 | Core chat logic + sidebar |
| `shared_widgets.dart` | ~479 | All reusable widgets |
| `chat_storage.dart` | ~190 | SQLite service |
| `wrapper.cpp` | 157 | Native inference pipeline |
| `profile_setup_screen.dart` | 333 | Onboarding UI |
| `splash_screen.dart` | ~215 | Launch animation |
| `app_theme.dart` | 103 | Theme system |
| `llm_service.dart` | 78 | FFI binding |
| `response_cleaner.dart` | 19 | Token stripping |
| `chat_message.dart` | 11 | Data model |
| `entry_point.dart` | 48 | Launch gate |
| `main.dart` | 58 | App entry |

**Total Dart:** ~3,000+ lines  
**Total C++:** ~160 lines  
**`flutter analyze`:** ✅ No issues found

---

*Document generated April 2026 — RAMA AI v1.2.0+3*
