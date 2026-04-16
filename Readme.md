## RAMA AI

RAMA AI is a 100% offline, on-device LLM chatbot for Android. It uses the llama.cpp library to run the Qwen2.5-1.5B-Instruct model locally on your device, without any internet connection.

### Features

- **100% Offline**: All processing happens on-device, no internet required
- **Privacy-Focused**: Your conversations stay on your device
- **Fast**: Optimized for mobile devices with GPU acceleration
- **Lightweight**: Small model size (around 1GB) that fits on most devices
- **Simple UI**: Clean, modern interface with chat history
- **Multi-turn Conversations**: Maintains context throughout your chat

### Getting Started

#### Prerequisites

- Android device with at least 2GB of RAM
- Android 8.0 (Oreo) or higher
- Flutter SDK installed

#### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd rama_ai
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

#### Downloading the Model

The first time you run the app, it will automatically download the Qwen2.5-1.5B-Instruct model (around 1GB). This requires an internet connection. Once downloaded, the model is stored locally and can be used offline.

### Usage

1. Open the app
2. Type your message in the chat input
3. Tap the send button
4. RAMA AI will respond instantly

### Model Information

- **Model**: Qwen2.5-1.5B-Instruct
- **Size**: ~1GB
- **Type**: 1.5 billion parameters, 4-bit quantization
- **License**: Apache 2.0
- **Performance**: ~15-20 tokens/second on mid-range devices

### Technical Details

RAMA AI uses the llama.cpp library for efficient LLM inference on mobile devices. The app includes:

- **FFI Bindings**: Direct communication with llama.cpp
- **Model Management**: Automatic model download and caching
- **Chat Storage**: Local SQLite database for conversation history
- **UI**: Flutter-based interface with Material Design

### Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

### License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

### Support

For issues or questions, please open an issue on the GitHub repository.