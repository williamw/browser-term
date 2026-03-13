# AGENTS.md

Guidelines for AI agents working on this repository.

## Project Overview

**Terminatab** is a Chrome extension that puts a terminal in your browser. A
lightweight local server written in Swift manages PTY sessions and exposes them
over WebSocket. The Chrome extension renders the terminal using
[xterm.js](https://xtermjs.org/) and connects to that local server. The backend
runs as a macOS menu bar app.

## Repository Layout

```
terminatab/
├── swift/            # Swift backend server (Swift Package Manager)
│   ├── Package.swift
│   ├── Resources/          # Info.plist, AppIcon.icns, menu bar icon PNGs
│   ├── Sources/Terminatab/
│   │   ├── App.swift              # macOS menu bar app (AppKit, NSStatusItem)
│   │   ├── Protocol.swift         # Wire message definitions (JSON)
│   │   ├── PTY.swift              # PTY session lifecycle (forkpty)
│   │   ├── SessionManager.swift   # Session manager (maps connection → PTY)
│   │   ├── WebSocketConnection.swift  # Per-connection WebSocket handler
│   │   └── WebSocketServer.swift  # WebSocket listener (Network.framework)
│   └── Tests/TerminatabTests/
│       ├── ProtocolTests.swift
│       ├── PTYTests.swift
│       └── SessionManagerTests.swift
├── extension/        # Chrome extension (Manifest v3)
│   ├── manifest.json
│   ├── background.js       # Service worker; routes icon clicks
│   ├── terminal.html       # Full-tab terminal page
│   ├── sidepanel.html      # Side-panel terminal page
│   ├── terminal.css
│   ├── terminal.js         # Terminal + WebSocket logic
│   ├── sidepanel-init.js   # Sidepanel bootstrap script
│   ├── terminal-init.js    # Full-tab terminal bootstrap script
│   ├── images/             # Extension icons (16/32/48/128 PNG + SVG)
│   ├── test.html           # In-browser test runner
│   ├── test.js             # Extension unit tests
│   └── lib/                # Vendored dependencies (xterm.js, etc.)
└── Makefile          # Build orchestration
```

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Swift 6.x (Swift Package Manager) |
| Networking | Network.framework (NWListener, NWConnection) |
| macOS GUI | AppKit (NSApplication, NSStatusItem) |
| Frontend | Vanilla JavaScript, Chrome Manifest v3 |
| Terminal renderer | xterm.js (vendored in `extension/lib/`) |

## Building

### Backend

```bash
cd swift && swift build -c release
```

To build a macOS `.app` bundle:

```bash
make app
```

This produces `Terminatab.app/` in the project root — a proper app bundle with
`LSUIElement=true` (no dock icon), an app icon, and the server binary.

### Extension

No build step. Load the `extension/` directory directly into Chrome (see below).

## Running

### Backend server

```bash
open Terminatab.app
```

Listens on `ws://localhost:7681`. The server runs as a macOS menu bar app (no
dock icon). The `>_` icon appears in the menu bar; click it and choose **Quit
Terminatab** to stop.

To view server logs:

```bash
log stream --predicate 'process == "Terminatab"' --level info
```

### Chrome extension

1. Open `chrome://extensions`.
2. Enable **Developer mode** (toggle, top-right).
3. Click **Load unpacked** and select the `extension/` directory.
4. Click the **Terminatab** icon in the toolbar — side panel opens on
   `http://https://` pages, a new terminal tab opens on everything else.

## Testing

### Backend unit tests

```bash
cd swift && swift test
```

Or via Make:

```bash
make test
```

Tests are in `swift/Tests/TerminatabTests/`. XCTest is used.

### Extension tests

Open `extension/test.html` in Chrome **after** loading the extension. The results
are displayed inline on the page.

## Code Conventions

- **Swift**: Follow the style already in `Sources/`. Use Swift concurrency
  (async/await, AsyncStream). Prefer structured concurrency where possible.
- **JavaScript**: Vanilla ES modules; no transpilation step. Keep logic in
  `terminal.js`; keep `background.js` minimal (service-worker constraints).
- **No linter configuration exists** for the extension. Match the surrounding code
  style when editing JS files.
- Keep vendored libraries in `extension/lib/` untouched unless upgrading them
  intentionally.

## Making Changes

- Backend changes require `swift build` and `swift test` to verify.
- Extension changes can be tested by reloading the unpacked extension in Chrome
  (`chrome://extensions` → reload button) and opening `extension/test.html`.
- Protocol changes (`Protocol.swift`) must be reflected in both the backend handler
  and the extension's `terminal.js`.

## Architecture Notes

### WebSocket server (`WebSocketServer.swift`)

Uses Network.framework's `NWListener` to accept TCP connections on port 7681.
Each connection is upgraded to WebSocket via `NWProtocolWebSocket.Options`. The
listener dispatches new connections to `WebSocketConnection` instances.

### WebSocket connection (`WebSocketConnection.swift`)

Each connection runs a receive loop using `NWConnection.receive()`. Incoming
messages are decoded via `Protocol.swift` and dispatched to create/attach/resize
PTY sessions.

### PTY management (`PTY.swift`)

Uses `forkpty()` from `util.h` to spawn shell processes. PTY output is read in
an async loop and forwarded to the WebSocket connection. Each PTY manages its
own file descriptor lifecycle.

### Session manager (`SessionManager.swift`)

Maps session IDs to PTY instances. Handles session creation, attachment, and
cleanup. Sessions persist across WebSocket reconnections until explicitly closed.

### macOS menu bar app (`App.swift`)

Creates an `NSApplication` with accessory activation policy (no dock icon). Sets
up an `NSStatusItem` with a template menu bar icon. Starts the WebSocket server
on launch. The app lifecycle is managed by AppKit's run loop.

### Extension icon click behavior

`background.js` routes the toolbar icon click: on `http://`/`https://` pages it
opens the side panel; on all other pages (new tab, `chrome://`, etc.) it opens a
new terminal tab.
