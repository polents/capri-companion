# Capri Companion

Capri is an original desktop companion for macOS and Windows. Her supplied PNG has a transparent background, so the portrait sits directly over the desktop in pet and chat views instead of inside a solid black rectangle.

## macOS

Requirements: macOS 13 or later and Xcode Command Line Tools for `swiftc`.

For a fresh copy, open Terminal and run:

```sh
git clone https://github.com/polents/capri-companion.git
cd capri-companion
bash ./run.sh
```

`run.sh` builds a universal Intel + Apple Silicon app when needed, installs it to `~/Applications/Capri Companion.app`, and starts it. The first build can take a little while. Keep Terminal open until it prints `Installed and started …` and the shell prompt returns. Then right-click Capri and choose **Chat**. On first use, she asks what to call you.

Optional **Screen Commentary** is available on macOS when enabled in Mainframe and after granting Screen Recording access. It uses on-device OCR and sends extracted text only to local Ollama; screenshots and OCR text are not saved.

## Windows PC

Windows 10/11 on x64 or ARM64. Ollama is optional for opening Capri and required for local AI replies. An internet connection is needed on first run to install the .NET 10 SDK and restore the Windows speech package.

Open PowerShell in the project folder and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-windows.ps1
```

The script installs the .NET SDK under your Windows user profile if needed, builds a self-contained app, installs it to `%LOCALAPPDATA%\Programs\Capri Companion`, and starts it. Right-click Capri for **Chat**, **Mainframe**, size controls, **Hide Capri**, and **Quit**. Use Capri's system tray icon to show her again. Closing Mainframe leaves Capri running.

On first launch, Capri asks what to call you. Chat, settings, and editable memories are saved locally under `%LOCALAPPDATA%\CapriCompanion`. Windows offers optional speech input and spoken replies. Screen commentary is not enabled in this Windows build; Capri does not inspect your screen.

## Local AI setup

Start Ollama and install the preferred model:

```sh
ollama pull gemma4:e4b
```

In Mainframe → Brain, choose another installed local model or enter a tag and pull it. If Ollama or the selected model is missing, Capri shows a setup message. She connects only to `http://127.0.0.1:11434`; chat and memories stay on your device, with no cloud fallback.

## Troubleshooting

### “destination path 'capri-companion' already exists”

The project folder is already there, so Git could not clone a second copy into the same location. Enter the existing folder and run the app:

```sh
cd ~/capri-companion
bash ./run.sh
```

To update an existing Git clone first, run `git pull` from inside that folder. Do not clone again unless you choose a different destination folder.

### “zsh: permission denied: ./run.sh”

Run the script through Bash; this does not require the executable permission bit:

```sh
bash ./run.sh
```

Or, from the project folder, set the permission once and then launch it directly:

```sh
chmod u+x ./run.sh
./run.sh
```

### Terminal has no prompt while `run.sh` is running

That means the build is still active. Leave Terminal open and wait for `Installed and started …` and the `%` prompt to return before typing another command. If an error appears, copy the final lines from Terminal. If `swiftc` is missing, install Apple's Command Line Tools with `xcode-select --install`, then run `bash ./run.sh` again.

## Contributors

Project credits (GitHub's automatic Contributors graph reflects commit authors):

- **@polents** — project owner and creative direction.
- **OpenAI Codex** — coding assistant.
- **Claude** — AI collaborator.
- **ChatGPT** — AI collaborator.

## Languages

- **Swift** — macOS companion app.
- **C#** and **XAML** — Windows companion app and WPF interface.
- **Bash** — macOS build and install launcher.
- **PowerShell** — Windows build and install launcher.
- **XML** — macOS app bundle metadata.

## Features

- Small always-on-top pet window with desktop dragging, idle motion, startup presets, and adjustable size.
- Click Capri to open chat; right-click for the pet menu.
- Mainframe controls appearance, personality, behavior, local Ollama model, optional voice, and user-managed memories.
- The Windows system tray and macOS menu bar can show Capri again after hiding her.
- Closing Mainframe does not close the pet.

Game control, call integration, and unrelated system monitoring are not included.
