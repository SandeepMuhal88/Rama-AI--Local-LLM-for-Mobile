<div align="center">

<h1>🤖 RAMA AI</h1>
<h3>100% Offline · On-Device · Privacy-First LLM Chatbot for Android</h3>

<p>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=white"/>
  <img src="https://img.shields.io/badge/C%2B%2B-17-00599C?logo=cplusplus&logoColor=white"/>
  <img src="https://img.shields.io/badge/llama.cpp-Native-orange"/>
  <img src="https://img.shields.io/badge/Version-2.0.0-blueviolet"/>
  <img src="https://img.shields.io/badge/License-Apache%202.0-green"/>
</p>

<p><strong>RAMA AI</strong> is a fully offline, on-device AI assistant built with Flutter + llama.cpp.
Your conversations never leave your phone — no cloud, no API keys, no internet needed.</p>

</div>

---

## 📱 Download APK (Ready to Install)

> **Prerequisite:** Android 8.0 (Oreo) or higher, ARM64 device with ≥ 2 GB RAM.

| File | Size | Notes |
|------|------|-------|
| `rama_ai_2.4.1.apk` | ~70 MB | ✅ **Recommended — Latest stable release** |
| `rama_ai_02.apk` | ~71 MB | Previous build |
| `app-debug.apk` | ~187 MB | Debug build (includes debug symbols) |

> 📂 APK files are located at:
> `RAMA-APP/rama_ai/build/app/outputs/flutter-apk/`

### Installing the APK

1. Copy `rama_ai_2.4.1.apk` to your Android phone.
2. On your phone, open **Settings → Security → Unknown Sources** and enable it
   *(or tap the APK and choose "Allow from this source" when prompted).*
3. Tap the APK to install.
4. On first launch, the app will guide you to download the AI model (~664 MB GGUF file).

---

## 🗂️ Project Structure

```
Local-LLM-For-Mobile/
├── RAMA-APP/
│   ├── rama_ai/                    # Flutter application
│   │   ├── lib/
│   │   │   ├── main.dart           # App entry point
│   │   │   ├── core/               # FFI bridge to llama.cpp
│   │   │   ├── screens/            # UI screens (chat, model manager, settings…)
│   │   │   ├── services/           # Inference & model download services
│   │   │   ├── storage/            # SQLite chat history
│   │   │   ├── models/             # Dart data models
│   │   │   ├── utils/              # Helpers & utilities
│   │   │   └── widgets/            # Reusable UI components
│   │   ├── android/
│   │   │   └── app/src/main/cpp/
│   │   │       ├── wrapper.cpp     # Native C++ inference wrapper
│   │   │       ├── CMakeLists.txt  # NDK build config
│   │   │       └── llama.cpp/      # Embedded llama.cpp library
│   │   ├── assets/icon/            # App icons
│   │   └── pubspec.yaml            # Flutter dependencies
│   ├── models/
│   │   └── model.gguf              # Local GGUF model file (~664 MB)
│   └── docs/
│       ├── ARCHITECTURE.md         # Deep-dive technical architecture
│       └── Technical-report.md     # Full technical report
└── Readme.md                       # ← You are here
```

---

## 🖥️ Setting Up a Fresh Development Environment

Follow these steps **in order** to set up RAMA AI on a brand-new Windows PC.

---

### Step 1 — Install Required Software

#### 1.1 Install Git
Download and install Git from: https://git-scm.com/download/win

```powershell
# Verify installation
git --version
```

#### 1.2 Install Flutter SDK

1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract the ZIP to `C:\flutter` (avoid paths with spaces).
3. Add Flutter to your **System PATH**:
   - Open **Start → Edit the system environment variables**
   - Under "System Variables", find **Path** → Edit → New
   - Add: `C:\flutter\bin`
4. Restart your terminal, then verify:

```powershell
flutter --version
flutter doctor
```

#### 1.3 Install Android Studio

1. Download from: https://developer.android.com/studio
2. During installation, check:
   - ✅ Android SDK
   - ✅ Android SDK Platform
   - ✅ Android Virtual Device (optional, for emulators)

3. After install, open Android Studio → **SDK Manager** → **SDK Tools** tab:
   - ✅ **Android NDK (Side by side)** — version `28.2.13676358` *(required)*
   - ✅ **CMake** (latest)
   - ✅ **Android SDK Command-line Tools**

4. Accept licenses:
```powershell
flutter doctor --android-licenses
```

#### 1.4 Install Java 17

Flutter requires Java 17. Android Studio bundles it — you can also install manually:

```powershell
# Check if Java is available through Android Studio's bundled JDK
# Or download Temurin JDK 17 from: https://adoptium.net/
java -version
```

Set `JAVA_HOME` environment variable to your JDK 17 path if needed.

---

### Step 2 — Clone the Repository

```bash
git clone https://github.com/SandeepMuhal88/Rama-AI--Local-LLM-for-Mobile.git
cd Rama-AI--Local-LLM-for-Mobile
```

---

### Step 3 — Configure Flutter for Android

```powershell
# Make sure Flutter finds your Android SDK
flutter config --android-sdk "C:\Users\<YourUser>\AppData\Local\Android\Sdk"

# Verify everything is set up correctly
flutter doctor -v
```

All items should show ✅ (except Chrome/Web if you don't need it).

---

### Step 4 — Install Flutter Dependencies

```powershell
cd RAMA-APP\rama_ai
flutter pub get
```

This installs all Dart/Flutter packages listed in `pubspec.yaml`:
- `ffi` — C++ FFI bindings
- `sqflite` — Local SQLite storage
- `dio` — HTTP downloads for model files
- `provider` — State management
- `google_fonts` — Premium typography
- `path_provider`, `permission_handler`, `file_picker`, etc.

---

### Step 5 — Verify NDK Version

Open `RAMA-APP/rama_ai/android/app/build.gradle.kts` and confirm:

```kotlin
ndkVersion = "28.2.13676358"
```

This exact NDK version is required to compile `llama.cpp` for ARM64.  
Install it via **Android Studio → SDK Manager → SDK Tools → NDK (Side by side)**.

---

### Step 6 — Build & Run

#### Option A: Run on a Physical Android Device (Recommended)

1. Enable **Developer Options** on your Android phone:
   - Go to **Settings → About Phone**
   - Tap **Build Number** 7 times
2. Enable **USB Debugging** in **Developer Options**
3. Connect your phone via USB cable
4. Authorize the connection on your phone when prompted

```powershell
# Check that your device is detected
flutter devices

# Run the app in debug mode
flutter run

# Or target a specific device
flutter run -d <device-id>
```

#### Option B: Build a Release APK

```powershell
cd RAMA-APP\rama_ai

# Build release APK (arm64-v8a only)
flutter build apk --release --target-platform android-arm64

# Output will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

#### Option C: Build a Debug APK

```powershell
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

---

### Step 7 — Download the AI Model

On first launch, the app will prompt you to download the AI model.

**Model Details:**
| Property | Value |
|----------|-------|
| Model | Qwen2.5-1.5B-Instruct |
| Format | GGUF (4-bit quantized, Q4_K_M) |
| Size | ~664 MB |
| Parameters | 1.5 Billion |
| License | Apache 2.0 |
| Source | Hugging Face |

The **Model Manager** screen inside the app handles downloading, verifying, and loading the model automatically.

> 💡 **Tip:** If you already have `model.gguf` locally, copy it to the app's storage using the **"Load Local File"** option in the Model Manager.

---

## ⚙️ Technical Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter UI (Dart)                 │
│  ChatScreen · ModelManager · Settings · Splash      │
└────────────────────┬────────────────────────────────┘
                     │ Provider State Management
┌────────────────────▼────────────────────────────────┐
│              Service Layer (Dart)                   │
│   LlamaInferenceService · ModelDownloadService      │
│   ChatStorageService (SQLite) · AppStateProvider    │
└────────────────────┬────────────────────────────────┘
                     │ Dart FFI (dart:ffi)
┌────────────────────▼────────────────────────────────┐
│           Native C++ Bridge (wrapper.cpp)           │
│   llama_init · llama_generate · llama_cleanup       │
│   Sliding-window context management                 │
└────────────────────┬────────────────────────────────┘
                     │ C API
┌────────────────────▼────────────────────────────────┐
│              llama.cpp (Android NDK)                │
│   ARM64 NEON · Multi-threaded inference             │
│   4-bit quantized GGUF model loading                │
└─────────────────────────────────────────────────────┘
```

### Key Technical Details

| Component | Technology | Notes |
|-----------|-----------|-------|
| UI Framework | Flutter 3.x / Dart | Cross-platform, hot-reload |
| AI Inference | llama.cpp (C++) | Compiled via Android NDK |
| FFI Bridge | dart:ffi | Zero-copy native calls |
| Model Format | GGUF Q4_K_M | 4-bit quantized for mobile |
| Storage | SQLite (sqflite) | Chat history persistence |
| State Mgmt | Provider | App-wide state |
| Architecture | ARM64-v8a | Android 8.0+ |
| NDK Version | 28.2.13676358 | Required for llama.cpp |
| Min SDK | 21 (Android 5.0) | Build target |
| Compile SDK | 36 | Latest Android |

---

## 🔧 Troubleshooting

###  `flutter doctor` shows Android SDK issues
```powershell
# Set Android SDK path explicitly
flutter config --android-sdk "C:\Users\<YourName>\AppData\Local\Android\Sdk"
flutter doctor --android-licenses
```

###  NDK not found / CMake error
- Open Android Studio → **SDK Manager → SDK Tools**
- Install **NDK (Side by side)** version `28.2.13676358`
- Install **CMake** (latest version)

###  Build fails with `llama.h: No such file`
The `llama.cpp` submodule must be present inside:
```
RAMA-APP/rama_ai/android/app/src/main/cpp/llama.cpp/
```
If the folder is empty, the submodule was not initialized:
```bash
git submodule update --init --recursive
```

###  App crashes on model load
- Ensure your device has at least **2 GB of FREE RAM**
- Use the Q4_K_M quantized model only (not larger variants)
- Check storage: the app needs ~1 GB free space

###  `flutter run` shows "No devices found"
- Enable USB Debugging on your Android device
- Try a different USB cable or port
- Run `adb devices` to check device visibility

###  Slow inference (< 5 tokens/second)
- Close background apps to free RAM
- Enable **Performance Mode** in device settings
- The app uses ARM NEON intrinsics for acceleration automatically

---

## 📋 Full Prerequisites Summary

| Tool | Version | Download |
|------|---------|----------|
| Flutter SDK | ≥ 3.x | https://flutter.dev |
| Dart SDK | ≥ 3.11.4 | Bundled with Flutter |
| Android Studio | 2023+ | https://developer.android.com/studio |
| Android NDK | 28.2.13676358 | Via Android Studio SDK Manager |
| CMake | Latest | Via Android Studio SDK Manager |
| Java JDK | 17 | Bundled with Android Studio |
| Git | Latest | https://git-scm.com |

**Device Requirements:**
- Android 8.0 (API 21+)
- ARM64-v8a processor (most phones since 2016)
- Minimum 2 GB RAM (4 GB recommended)
- ~1.5 GB free storage (for model + app data)

---

## 📦 Dependencies

```yaml
# Core Flutter packages used in this project
ffi:              ^2.1.0       # C++ native bridge
path_provider:    ^2.1.2       # App storage paths
path:             ^1.9.0       # Path utilities
shared_preferences: ^2.3.2    # Lightweight key-value storage

# Networking & files
dio:              ^5.4.0       # Model download with progress
file_picker:      ^8.1.2       # Local GGUF file selection

# Permissions
permission_handler: ^11.3.1   # Android storage permissions

# Storage
sqflite:          ^2.3.3       # Chat history database

# Utilities
intl:             ^0.19.0      # Internationalization
device_info_plus: ^10.1.0      # Hardware info display

# UI & State
google_fonts:     ^6.2.1       # Premium typography
provider:         ^6.1.2       # State management
```

---

## 🏃 Quick-Start Commands Cheatsheet

```powershell
# 1. Clone
git clone https://github.com/SandeepMuhal88/Rama-AI--Local-LLM-for-Mobile.git
cd Rama-AI--Local-LLM-for-Mobile\RAMA-APP\rama_ai

# 2. Get packages
flutter pub get

# 3. Check setup
flutter doctor

# 4. Run on device
flutter run

# 5. Build release APK
flutter build apk --release --target-platform android-arm64

# 6. Install APK directly
flutter install
```

---

## 📄 License

This project is licensed under the **Apache 2.0 License**.
See [LICENSE](LICENSE) for details.

The embedded `llama.cpp` library is separately licensed under the **MIT License**.
The Qwen2.5-1.5B-Instruct model is licensed under **Qwen License Agreement**.

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📞 Support

- 🐛 **Bug Reports**: Open a GitHub Issue
- 💬 **Questions**: Open a GitHub Discussion
- 📖 **Deep Technical Docs**: See [`docs/ARCHITECTURE.md`](RAMA-APP/docs/ARCHITECTURE.md)

---

<div align="center">
Made with ❤️ by Sandeep Muhal &nbsp;|&nbsp; RAMA AI v2.0.0
</div>
