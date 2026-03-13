# Terminatab

A Chrome extension that puts a terminal in your browser. Powered by a
lightweight local Swift server that manages PTY sessions over WebSocket.

## Prerequisites

- Swift 6.x / Xcode 16+ (for building the backend)
- macOS 15+
- GNU Make
- Google Chrome (for the extension)

## Quick Start

### 1. Clone the repo

```
git clone https://github.com/williamw/terminatab.git
cd terminatab
```

### 2. Build everything

```
make
```

This builds the macOS `.app` bundle and packages the Chrome extension into a
`.zip` file, both in the project root:

- `Terminatab.app` — macOS menu bar app
- `terminatab-extension.zip` — Chrome extension (ready for Web Store upload)

You can also build them individually:

```
make app        # just the macOS app
make extension  # just the Chrome extension zip
make clean      # remove build artifacts
```

### 3. Run the backend

```
open Terminatab.app
```

The server starts on `ws://localhost:7681` and runs as a menu bar app — look for
the **>_** icon in the menu bar. It daemonizes automatically (the shell returns
immediately). Click the icon and choose **Quit Terminatab** to stop it.

To view server logs on macOS:

```
log stream --predicate 'process == "Terminatab"' --level info
```

### 4. Install the Chrome extension

**From the Chrome Web Store** (recommended): Upload `terminatab-extension.zip`
to the [Chrome Developer Dashboard](https://chrome.google.com/webstore/devconsole)
and install from your listing.

**Load unpacked** (for development):

1. Open Chrome and navigate to `chrome://extensions`
2. Enable **Developer mode** (toggle in the top-right)
3. Click **Load unpacked**
4. Select the `extension/` directory from this repo

### 5. Use it

- **Side panel**: Click the Terminatab icon on any `http://` or `https://` page.
  The terminal opens in Chrome's side panel alongside your current tab.
- **Full tab**: Click the icon on any other page (new tab, `chrome://` pages,
  etc.) to open a terminal in the current tab.
- **Pop out**: Click the pop-out button in the side panel to move the terminal
  to its own full tab.

Each tab/panel gets its own independent shell session.

### 6. MCP Integration (optional)

Terminatab includes a [Model Context Protocol](https://modelcontextprotocol.io/)
server that lets AI tools like Claude Code interact with your Chrome tabs.

**Tools available:**

- `list_tabs` — list all open Chrome tabs
- `screenshot` — capture a screenshot of any tab
- `evaluate_javascript` — run JavaScript in a tab's page context
- `get_page_content` — get the full HTML of a tab

**Setup:**

1. Click the **>_** menu bar icon and choose **Enable DevTools MCP**.
2. Click **Copy MCP Config** from the same menu.
3. Paste the config into your Claude Code MCP settings.

The MCP server runs on `http://localhost:7682/mcp`. Toggle it on/off from the
menu bar — the menu item shows how many tabs are attached when enabled.

## Development

### Run backend tests

```
make test
```

Or directly:

```
cd swift && swift test
```

### Run extension tests

Open `extension/test.html` in Chrome after loading the extension.

## Architecture

```
                                                ┌──────────────────────┐
┌─────────────────────┐       WebSocket         │   Swift Backend        │
│   Chrome Extension   │ ◄──────────────────► │  • PTY management      │
│  • xterm.js UI       │    localhost:7681     │  • WebSocket server    │
│  • Side panel        │                       │  • Shell spawning      │
│  • Full tab          │       WebSocket        │  • MCP HTTP server     │
│  • DevTools bridge   │ ◄──────────────────► │  • Menu bar app        │
│    (chrome.debugger) │   MCP control channel  │                        │
└─────────────────────┘                        └───────────┬────────────┘
                                                           │ HTTP
                                               ┌───────────┴────────────┐
                                               │   MCP Clients            │
                                               │  (Claude Code, etc.)     │
                                               │   localhost:7682/mcp     │
                                               └──────────────────────────┘
```

The Swift backend spawns PTY sessions and serves them over WebSocket using
Network.framework. The Chrome extension renders the terminal using xterm.js and
connects to the backend. Each tab or panel gets its own independent shell
session. The backend also runs an MCP server on port 7682 that routes tool calls
through the extension's DevTools bridge to Chrome's debugger API, enabling AI
tools to inspect and interact with browser tabs. The backend runs as a macOS
menu bar app with no dock icon.

## License

MIT
