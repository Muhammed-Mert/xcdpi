# XCDPI - Linux Transparent DPI Bypass & Strategy Scanner 🚀

[![Version: v0.1-beta](https://img.shields.io/badge/Version-v0.1--beta-orange.svg)](https://github.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.kernel.org/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![AI-Assisted](https://img.shields.io/badge/AI--Assisted-Antigravity--AI-purple.svg)](https://deepmind.google/)

**XCDPI v0.1-beta** is a modern, lightweight, and session-based Linux command-line utility designed to bypass Deep Packet Inspection (DPI) censorship and network throttling. Powered by **ByeDPI / ciadpi** and **iptables** transparent port redirection, XCDPI automatically scans **35+ TCP desynchronization strategies** to unblock censored websites and desktop applications (such as Discord, Spotify, Steam, and web browsers) system-wide without requiring any proxy settings in your browser or system network control panel.

---

## 🤖 AI Attribution & Pair Programming

This project was engineered in pair-programming collaboration with **Google DeepMind's Antigravity AI**. The DPI desynchronization routines, dynamic CLI interface, multi-endpoint strategy verification engine, and iptables owner-matching loop avoidance mechanisms were designed and optimized with AI assistance.

---

## ✨ Features

- **⚡ System-Wide Transparent Redirection**:
  No browser extension or manual proxy setup required. XCDPI uses `iptables` transparent redirection to filter system-wide outgoing TCP traffic on ports `80` and `443`.
- **🌐 35+ Universal Desynchronization Strategies**:
  Automatically benchmarks 35 desynchronization techniques including TLS Record Splitting, Out-of-Order segment injection (Disorder), Out-of-Bound byte insertion (Disoob), Fake SNI payload injection with custom TTL distances (1–4 hops), and Heuristic Auto-Desync engines.
- **🛡️ Session-Based Teardown**:
  Runs cleanly in your terminal session. Pressing `Ctrl+C` or running `xcdpi --stop` immediately removes `iptables` redirection rules and kills background daemons, restoring your internet connection to its original state.
- **⚡ Non-Interactive CLI Automation**:
  Connect instantly with `xcdpi -y` (using last saved strategy) or scan specific domains on-the-fly with `xcdpi -d domain.com`.

---

## 🛠️ Installation

Clone the repository and run the installer script:

```bash
git clone https://github.com/your-username/XCDPI.git
cd XCDPI
./install.sh
```

The installer links `xcdpi` to `~/.local/bin/xcdpi`. Ensure `~/.local/bin` is in your `$PATH`.

---

## 🚀 Usage Guide

### Interactive CLI Menu
Simply run `xcdpi` in your terminal to launch the interactive menu:

```bash
xcdpi
```

### CLI Command Options

```bash
# Connect automatically using the last working strategy (non-interactive):
xcdpi -y

# Scan 35+ strategies for a specific target domain and connect automatically:
xcdpi -d instagram.com

# Stop active XCDPI session and restore network settings:
xcdpi --stop

# Update XCDPI script files while preserving saved strategies (~/.xcdpi):
xcdpi -u

# Show command help:
xcdpi -h
```

---

## 🎯 Supported Strategies Summary

| Category | Description | Target Use Case |
|---|---|---|
| **TLS Record Split** | Splits TLS Client Hello record bytes | Discord, Cloudflare, HTTPS |
| **Disorder** | Out-of-order TCP segment injection | Sandvine, Huawei SIG DPI |
| **Disoob / OOB** | Out-of-Bound byte stream confusion | Deep stateful inspection |
| **Fake SNI + TTL** | Sends spoofed SNI packets with low TTL | ISP middlebox TTL filtering |
| **Hybrid Desync** | Combines record split, fake SNI & TTL | Strict ISP DPI hardware |
| **Heuristic Engine** | Auto-learning desynchronization levels | Dynamic network filtering |

---

## 🧹 Uninstallation

To remove XCDPI from your system:

```bash
xcdpi --uninstall
```
*(or run `./uninstall.sh` directly)*

---

## 📜 License

Distributed under the **MIT License**. See `LICENSE` for more information.
