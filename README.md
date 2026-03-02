# broweser-term

A Chrome extension that embeds a live terminal 
alongside your browser tabs. Powered by a 
lightweight local server built on libghostty 
to manage PTY sessions under the hood.​​​​​​​​​​​​​​​​

## Prerequisites

- [Zig 0.14.x](https://ziglang.org/download/) (for building the backend)
- Google Chrome (for the extension)

## Quick Start

### 1. Clone the repo

```
git clone https://github.com/williamw/browser-term.git
cd browser-term
```

### 2. Build and run the backend

```
cd backend
zig fetch --save "git+https://github.com/karlseguin/websocket.zig#zig-0.14"
zig build
./zig-out/bin/browser-term-server
```

The first command fetches the WebSocket dependency and updates `build.zig.zon` with
the correct hash. You only need to run it once. The server starts on
`ws://localhost:7681`.

The server runs as a foreground process — it logs to stdout and you stop it with
Ctrl+C. Keep this terminal window open while using the extension.

### 3. Load the Chrome extension

1. Open Chrome and navigate to `chrome://extensions`
2. Enable **Developer mode** (toggle in the top-right)
3. Click **Load unpacked**
4. Select the `extension/` directory from this repo

### 4. Use it

- **Side panel mode**: Click the Terminal Companion icon on any regular web page.
  The terminal opens in Chrome's side panel alongside your current tab.
- **Full tab mode**: Click the icon on a new tab page, or bookmark
  `chrome-extension://<YOUR_EXTENSION_ID>/terminal.html` for quick access.
- **Pop out**: Click the pop-out button in the side panel to move the terminal
  to its own full tab.

Each tab/panel gets its own independent shell session.

## Development

### Run backend tests

```
cd backend
zig build test
```

### Run extension tests

Open `extension/test.html` in Chrome after loading the extension.

## Architecture

```
┌─────────────────────┐       WebSocket        ┌──────────────────────┐
│   Chrome Extension   │ ◄──────────────────► │   Zig Backend         │
│  • xterm.js UI       │    localhost:7681     │  • PTY management     │
│  • Side Panel mode   │                       │  • WebSocket server   │
│  • Full tab mode     │                       │  • Shell spawning     │
└─────────────────────┘                        └──────────────────────┘
```

The Zig backend spawns PTY sessions and serves them over WebSocket. The Chrome
extension renders the terminal using xterm.js and connects to the backend. Each
tab or panel gets its own independent shell session.

## License

MIT
