# MLX AI

<p align="center"><img src="Resources/AppIcon-master.png" width="160" alt="MLX AI icon"></p>
<p align="center"><strong>A polished macOS menu-bar controller for local MLX language models.</strong></p>

<p align="center">
  <a href="https://github.com/k6w/mlx-ai-app/actions/workflows/ci.yml"><img src="https://github.com/k6w/mlx-ai-app/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2ea44f" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black" alt="macOS 13+">
</p>

MLX AI starts, monitors, and stops an OpenAI-compatible [`mlx_lm.server`](https://github.com/ml-explore/mlx-lm) without keeping a terminal open. The server is bound to localhost and managed by launchd, so the menu app and companion CLI always agree.

> MLX AI is an independent open-source project and is not affiliated with or endorsed by Apple or the MLX project.

## Features

- Native SwiftUI/AppKit menu-bar experience with live status, memory, uptime, and diagnostics.
- Start, stop, and restart a launchd-managed server that survives UI restarts.
- First-run installation of isolated Python 3.11 and pinned `mlx-lm`—no administrator access or system Python changes.
- OpenAI-compatible API at `http://127.0.0.1:8080/v1`.
- Optional companion CLI with human-readable and JSON status.
- Failure notifications, login controls, safe log rotation, and external-process protection.
- Signed and notarized DMG release pipeline for Apple Silicon Macs.

## Screenshots

<table>
  <tr>
    <td align="center"><strong>Running · Dark</strong></td>
    <td align="center"><strong>Stopped · Light</strong></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mlx-ai-running-dark.png" alt="MLX AI menu showing a healthy running model in dark mode" width="336"></td>
    <td><img src="docs/screenshots/mlx-ai-stopped-light.png" alt="MLX AI menu showing the stopped state in light mode" width="336"></td>
  </tr>
</table>

<p align="center"><strong>Private, guided first-run setup</strong></p>
<p align="center"><img src="docs/screenshots/mlx-ai-first-run.png" alt="MLX AI first-run runtime installation screen" width="336"></p>

## Requirements

- Apple Silicon Mac running macOS 13 Ventura or newer
- Internet access during first setup and first model launch
- Roughly 5 GB of disk space and memory for the default model

## Install

1. Download the latest `MLX-AI-*.dmg` from [Releases](https://github.com/k6w/mlx-ai-app/releases/latest).
2. Drag **MLX AI** to Applications.
3. Open it and choose **Install Runtime**.
4. Click **Start Server**. The default model downloads on first use.

The runtime lives under `~/Library/Application Support/MLX AI`. Existing installations using `~/.mlx-venv` are adopted automatically.

Install the optional terminal command from MLX AI Settings:

```sh
mlx-ai                  # start and wait until ready
mlx-ai status           # health, model, memory, and uptime
mlx-ai status --json    # stable machine-readable output
mlx-ai stop             # stop and release model memory
mlx-ai restart
mlx-ai logs --follow
mlx-ai doctor
```

## Build from source

Install Xcode or matching Xcode Command Line Tools, then:

```sh
make test
make app
make dmg
```

For a clean-Mac bootstrap, place arm64 `uv` on `PATH` or set `UV_BINARY=/path/to/uv`. Without it, the app can adopt an existing environment but cannot install a new one.

Local builds are ad-hoc signed. Release signing uses `MACOS_SIGN_IDENTITY`; see [RELEASING.md](RELEASING.md).

Maintainers can regenerate the production UI screenshots without capturing the desktop:

```sh
'.build/MLX AI.app/Contents/MacOS/MLXAI' --export-screenshots "$PWD/docs/screenshots"
```

## Architecture

- `MLXAI`: accessory app using `NSStatusItem`, `NSPopover`, and SwiftUI.
- `MLXAIKit`: runtime bootstrap, health checks, launchd lifecycle, metrics, and state machine.
- `mlx-ai`: standalone CLI built from the same controller library.

Runtime data:

- Configuration: `~/Library/Application Support/MLX AI/config.json`
- Managed runtime: `~/Library/Application Support/MLX AI/runtime`
- Server log: `~/Library/Logs/MLX AI/server.log`
- Launch agent: `~/Library/LaunchAgents/com.drwn.mlxai.server.plist`

The API host is fixed to `127.0.0.1`; `mlx_lm.server` is not a production-secured network service.

Contributions are welcome—read [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

Licensed under the [MIT License](LICENSE).
