# 🚀 SoloDrop — Instant Local File Sharing

**SoloDrop** is a lightweight, ultra-fast cross-platform application for transferring files, photos, and text between your devices in a local network with just one click.

## ❓ Why use it?
Imagine you need to transfer a heavy video or a bunch of photos from an iPhone to a Windows PC, or copy a long text from a PC to a phone. With SoloDrop, it takes just a couple of seconds without messaging yourself, using USB flash drives, or dealing with complex configurations.

## ✨ Key Features
* **End-to-End P2P Transfer:** Files are transferred directly between devices via Wi-Fi, bypassing third-party clouds and internet servers. Maximum speed of your router!
* **Absolute Privacy:** Your data is never saved on the internet. Everything stays strictly inside your home or office local network.
* **Cross-Platform:** Native iOS client (SwiftUI) and a universal PC server (Python).
* **One-Tap Exchange:** Drag-and-Drop interface — simply drag a file or choose a device from the discovered list.

## 🛠 Project Architecture
The project is split into three main components:
1. `pc_server/` — PC server application written in **Python**. Includes automation launch scripts for Windows (`.cmd`, `.ps1`, `.vbs`) and macOS (`.sh`).
2. `ios_swiftui/` — Native iOS mobile app built with the **SwiftUI** framework.
3. `ios_webview/` — Alternative hybrid/WebView version of the iOS client.

## 💻 Quick Start (PC Server)

### Requirements
* Python 3.10 or higher

### Installation & Run
1. Install the required dependencies:
   ```bash
   pip install -r pc_server/requirements.txt
   ```
2. Start the server:
   ```bash
   python pc_server/main.py
   ```
   *(Or use the ready-made scripts like `start_windows.ps1` or `start_macos.sh` inside the server folder).*
