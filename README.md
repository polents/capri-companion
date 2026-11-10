# Capri Companion

Capri is an original desktop companion with a floating, transparent character window. Her supplied PNG has a transparent background, including in chat, so she sits directly over the desktop instead of inside a black rectangle.

## Windows PC

Windows 10/11 on x64 or ARM64. Ollama is optional for opening Capri and required for local AI replies. An internet connection is needed the first time to install the .NET 10 SDK and restore the Windows speech package.

1. Open PowerShell in this project folder.
2. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-windows.ps1
   ```

The script installs the .NET SDK under your Windows user profile if needed, builds a self-contained Windows app, installs it to `%LOCALAPPDATA%\Programs\Capri Companion`, and starts it. Right-click Capri for **Chat**, **Mainframe**, size controls, **Hide Capri**, and **Quit**. If hidden, use the Capri icon in the system tray to show her again. Closing Mainframe leaves Capri running.

On first launch, Capri asks what to call you. Chat, settings, and editable memories are saved locally under `%LOCALAPPDATA%\CapriCompanion`. The Windows build offers optional Windows speech input and spoken replies. Screen commentary is not enabled in this Windows build; Capri does not inspect your screen.

## macOS

Requirements: macOS 13 or later and Xcode Command Line Tools for `swiftc`.

1. Open Terminal and `cd` to this folder.
2. Run `./run.sh`. It compiles a universal Intel + Apple Silicon app when needed, installs it to `~/Applications/Capri Companion.app`, and starts the installed copy.
3. Right-click Capri and choose **Chat**. On first use, she asks what to call you.

Optional screen commentary is available on macOS when you enable it in Mainframe and grant Screen Recording access. It uses on-device OCR and sends extracted text only to the local Ollama model; screenshots and OCR text are not saved.

## Local AI setup

Start Ollama and install the preferred model:

```sh
ollama pull gemma4:e4b
```

In Mainframe → Brain, you can choose another installed local model or enter a tag and pull it. If Ollama or the selected model is missing, Capri shows a setup message. She connects only to `http://127.0.0.1:11434`; chat and memories are not sent to a cloud service and there is no cloud fallback.

## Features

- Small always-on-top pet window with native desktop dragging, idle motion, startup presets, and adjustable size.
- Click Capri to open chat; right-click for the pet menu.
- Mainframe controls appearance, personality, behavior, local Ollama model, optional voice, and user-managed memories.
- Windows tray icon and macOS menu bar controls can show Capri again after hiding her.
- Closing Mainframe does not close the pet.

Game control, call integration, and unrelated system monitoring are not included.
