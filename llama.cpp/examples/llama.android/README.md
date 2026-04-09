# TinyLlama Offline Assistant for Android

This Android sample has been upgraded from a basic GGUF picker into a practical offline assistant flow:

- It imports a GGUF model into app-private storage the first time you pick it.
- It automatically restores the last imported model on the next launch.
- It applies a built-in assistant system prompt after every model load.
- It lets you stop generation and reset the conversation without reinstalling the app.

## TinyLlama model already in this repo

The repo already includes a mobile-friendly TinyLlama GGUF here:

`../../models/tinyllama-1.1b-chat-v1.0-q4_k_m.gguf`

## Fast path: push TinyLlama to your phone

If you have `adb` installed and a device connected, run:

```powershell
.\scripts\push-tinyllama-to-download.ps1
```

That copies the bundled TinyLlama file to:

`/sdcard/Download/tinyllama-1.1b-chat-v1.0-q4_k_m.gguf`

## Build and run

1. Open `examples/llama.android` in Android Studio.
2. Sync Gradle and build the app.
3. Launch the app on an Android device.
4. Tap `Import model`.
5. Pick the TinyLlama GGUF from the device's `Download` folder.

After the first import, the app uses its own local private copy, so future launches stay fully offline and do not require picking the model again.

## Notes

- The Android native sample now uses a smaller default context and batch size to fit mobile memory more comfortably.
- Replies are capped to 256 generated tokens by default to keep mobile responses responsive.
- If you want to completely restart the conversation state, use `Reset chat`.
