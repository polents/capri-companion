# Capri Companion

Capri is a macOS desktop pet with a floating, transparent character window. The supplied portrait is used as her sprite, and the chat panel follows the second screenshot's prompt bar, character, and compact controls.

## Run

Requirements: macOS 13 or later and Xcode Command Line Tools (for `swiftc`). Ollama is optional for opening the app, and required for local AI replies.

1. Open Terminal and `cd` to this folder.
2. Run `./run.sh`. The script compiles a universal Intel + Apple Silicon app when needed, installs it to `~/Applications/Capri Companion.app`, and starts the installed copy. If Launch Services declines the locally built bundle, the script starts the installed executable directly.
3. Right-click Capri and choose **Chat**. On first use, she asks what to call you in the chat prompt.
4. For chat, start Ollama and install the preferred model:

   ```sh
   ollama pull gemma4:e4b
   ```

   If the exact tag is unavailable, Mainframe can use an installed model whose name includes both `gemma4` and `e4b`. In Mainframe → Brain, you can select another installed local model or enter a model tag and use **Pull selected model**.

The app talks only to `http://127.0.0.1:11434`. It does not send data to a cloud model, and it does not fall back to one if Ollama is unavailable. Chat, settings, and memories are stored locally in this macOS user account. Voice input uses on-device macOS speech recognition only while you explicitly start the microphone; if on-device recognition is unavailable, the mic remains off. Spoken replies use the selected built-in macOS voice.

## Controls

- Click Capri to open chat. Right-click her for **Talk to her**, **Sit here**, and **Move**, **Size**, **Brain**, and **Settings** submenus. Drag her to move her; **Sit here** locks her in place.
- Change her size from **Mainframe → Pet Scale** or the right-click **Size** submenu.
- The cyan `> you:` prompt sits above Capri; press Return to send. Her replies appear between the prompt and portrait.
- Use the menu bar bird icon to show Capri or open Mainframe.
- Mainframe is a separate cyberpunk control panel. Closing it leaves Capri on the desktop. It includes startup presets, pet scale, personality sliders, quiet mode and check-in timing, Ollama status/model selection, optional voice controls, and editable memories.
- Optional **Screen Commentary** uses macOS Screen Recording permission and on-device Vision OCR. It sends only extracted text to the selected local Ollama model, does not save screenshots or OCR text, and pauses in Quiet Mode. It is off until you enable it and grant permission.
- Check-ins wait until the selected idle interval has passed. Set the interval to **Off**, set proactivity to **Quiet**, or enable **Quiet Mode** to turn them off.

Game control, call integration, and unrelated system monitoring are not included.
