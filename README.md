# 🍃 Menochat (মেনোচ্যাট) - Offline Voice Assistant

Menochat is a privacy-first, fully offline Bengali voice assistant built with SwiftUI. It leverages Apple's native Speech framework for highly accurate Bengali voice recognition and relies on a locally hosted LLaMA/Gemma model (via llama.cpp) to generate AI responses completely offline.

---

## ✨ Features

- **100% Offline AI:** Generates responses locally on your device without sending data to the cloud.
- **Native Bengali Voice Recognition:** Utilizes Apple's built-in Speech framework tailored for accurate Bengali transcription.
- **Text-to-Speech (TTS):** Reads AI responses out loud natively in Bengali.
- **Privacy-First:** All processing, from voice recognition to AI generation, happens directly on your iPhone hardware.

---

## 🚀 How to Run the Project

Follow these steps to set up and run Menochat locally on your physical iPhone.

### 1. Clone the Repository

Open your terminal and clone the project to your local machine:

```bash
git clone https://github.com/mahbubasif/menochat-swiftui.git
cd menochat-swiftui
```

### 2. Download the Offline AI Model

Because AI models exceed GitHub's file size limits, you must download the offline model manually:

1. Visit the Hugging Face repository: **afi-gemma4-e2b-merged-gguf**.
2. Download the required model file (e.g., the `.gguf` or `.bin` file).
3. Move the downloaded model file directly into the `/examples/llama.cpp/examples/llama.swiftui/llama.swift/Resources/models` folder inside your cloned project directory.

### 3. Build the XCFramework

Before opening the project in Xcode, you need to compile the C++ backend for iOS. Run the following command in your terminal from the root of the project:

```bash
./build-xcframework.sh
```

### 4. Build and Install via Xcode

1. Open the project in Xcode.
2. Select your physical iPhone from the device dropdown menu at the top of the Xcode window.

> ⚠️ **Important:** The iOS Simulator does not support Apple's native microphone sample rates or the hardware AI acceleration required for this app. You must use a physical device.

3. If this is your first time building an app on this device, navigate to your project's **Signing & Capabilities** tab and select your **Personal Team** to sign the app.
4. Press `CMD + R` (or click the Play button) to build and install the app onto your iPhone.

---

## 💡 Important Notes for Testing

- **Audio Output:** Ensure your iPhone's physical ringer/silent switch is turned **ON** (not on silent mode) and your media volume is up so the Text-to-Speech (TTS) engine can read the AI responses out loud.
- **Permissions:** The app will request **Microphone** and **Speech Recognition** permissions on its first launch. You must accept both for the voice interface to function properly.
