# AGENTS.md

Guidelines for AI agents working on this repository.

## Project Overview

**Terminatab** is a Chrome extension that embeds a live
terminal alongside browser tabs. A lightweight local server written in Zig manages
PTY sessions and exposes them over WebSocket. The Chrome extension renders the
terminal using [xterm.js](https://xtermjs.org/) and connects to that local server.

## Repository Layout

```
terminatab/
├── backend/          # Zig backend server
│   ├── build.zig     # Zig build configuration
│   ├── build.zig.zon # Package manifest & dependency hashes
│   └── src/
│       ├── main.zig        # Server entry point; WebSocket listener
│       ├── protocol.zig    # Wire message definitions
│       ├── pty.zig         # PTY session lifecycle
│       ├── session.zig     # Session manager (maps connection → PTY)
│       └── ws_handler.zig  # WebSocket upgrade & frame handling
└── extension/        # Chrome extension (Manifest v3)
    ├── manifest.json
    ├── background.js       # Service worker; routes panel/tab actions
    ├── terminal.html       # Full-tab terminal page
    ├── sidepanel.html      # Side-panel terminal page
    ├── terminal.css
    ├── terminal.js         # Shared xterm.js + WebSocket logic
    ├── sidepanel-init.js   # Sidepanel bootstrap script
    ├── terminal-init.js    # Full-tab terminal bootstrap script
    ├── test.html           # In-browser test runner
    ├── test.js             # Extension unit tests
    └── lib/                # Vendored dependencies (xterm.js, etc.)
```

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Zig 0.14.x |
| Backend dependency | [websocket.zig](https://github.com/karlseguin/websocket.zig) (zig-0.14 branch) |
| System dependency | `libutil` (Linux) / `util.h` (macOS) — provides `forkpty()` |
| Frontend | Vanilla JavaScript, Chrome Manifest v3 |
| Terminal renderer | xterm.js (vendored in `extension/lib/`) |

## Building

### Backend

```bash
cd backend
zig build
```

The binary is placed at `backend/zig-out/bin/terminatab-server`.

> **Upgrading websocket.zig**: Run `zig fetch --save "git+https://github.com/karlseguin/websocket.zig#zig-0.14"` to update the pinned hash in `build.zig.zon`.

### Extension

No build step. Load the `extension/` directory directly into Chrome (see below).

## Running

### Backend server

```bash
./backend/zig-out/bin/terminatab-server
```

Listens on `ws://localhost:7681`. Runs in the foreground; stop it with `Ctrl+C`.

### Chrome extension

1. Open `chrome://extensions`.
2. Enable **Developer mode** (toggle, top-right).
3. Click **Load unpacked** and select the `extension/` directory.
4. Click the **Terminatab** icon in the toolbar to open the side panel or full-tab terminal.

## Testing

### Backend unit tests

```bash
cd backend
zig build test
```

Tests are defined inline (Zig `test` blocks) in each `src/*.zig` file. The build
system runs them all via `zig build test`.

### Extension tests

Open `extension/test.html` in Chrome **after** loading the extension. The results
are displayed inline on the page.

## Code Conventions

- **Zig**: Follow the style already in `src/`. Prefer explicit error handling (`try`
  / `catch`); avoid `unreachable` except where truly invariant.
- **JavaScript**: Vanilla ES modules; no transpilation step. Keep logic in
  `terminal.js`; keep `background.js` minimal (service-worker constraints).
- **No linter configuration exists** for the extension. Match the surrounding code
  style when editing JS files.
- Keep vendored libraries in `extension/lib/` untouched unless upgrading them
  intentionally.

## Making Changes

- Backend changes almost always require `zig build` and `zig build test` to verify.
- Extension changes can be tested by reloading the unpacked extension in Chrome
  (`chrome://extensions` → reload button) and opening `extension/test.html`.
- Protocol changes (`protocol.zig`) must be reflected in both the backend handler
  and the extension's `terminal.js`.
- The `build.zig.zon` file contains a pinned hash for the `websocket.zig`
  dependency. Re-run `zig fetch --save ...` if you need to change the dependency
  version; commit the updated `build.zig.zon`.

## Architecture Notes

### WebSocket server (`main.zig`)

The server uses [websocket.zig](https://github.com/karlseguin/websocket.zig)'s
`websocket.Server(WsHandler)`. The `WsHandler` struct must implement:

- `init(handshake, conn, ctx) !WsHandler` — called on each new WebSocket connection
- `clientMessage(self, data) !void` — called for each incoming text frame
- `close(self) void` — called when the connection closes

A shared `Context` struct (holding `*SessionManager` and `allocator`) is passed to
`server.listen(&ctx)` and forwarded to each handler's `init`.

### PTY read loop

Each WebSocket connection spawns a dedicated thread (`ptyReadLoop`) after a
`new_session` or `attach` message creates/binds a session. The thread:

1. Reads from `session.pty.read()` in a loop
2. Serializes output via `protocol.serializeServerMessage(.output, ...)`
3. Sends it over the WebSocket via `conn.write(json)`
4. Exits when the session ends, WebSocket closes, or `should_stop` is set

### Handler generics

`ws_handler.Handler(Conn)` is generic over the connection type. Any type with a
`write([]const u8) !void` method works. In production it uses `websocket.Conn`;
tests use `MockConn` (an `ArrayList`-backed stub defined in `ws_handler.zig`).

### macOS PTY support

`forkpty()` lives in different headers per platform: `util.h` on macOS, `pty.h` on
Linux. This is handled via a compile-time `@cImport` conditional in `pty.zig`.
