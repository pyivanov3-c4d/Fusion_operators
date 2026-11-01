# Fusion MCP

An [MCP](https://modelcontextprotocol.io) server that drives a **running Blackmagic
Fusion Studio** instance through its scripting bridge (`fusionscript`), letting an
LLM assistant inspect, build, modify and render comps. It talks to your *live* Fusion
session — the counterpart to a DaVinci Resolve MCP.

## Requirements

- **Fusion Studio** running (external scripting is enabled by default in Studio; the
  free Fusion Render Node also exposes the same bridge).
- **Python 3.9–3.11** that can load Fusion's `fusionscript` C extension. The same
  Python is used to run the server.
- The `mcp` package (`pip install mcp`).

## Install

```bash
git clone https://github.com/<you>/fusion-mcp
cd fusion-mcp
python -m venv venv
# Windows:  venv\Scripts\pip install mcp
# macOS/Linux:  venv/bin/pip install mcp
```

The server auto-detects `fusionscript.dll` / `fusionscript.so` in the usual install
locations (Fusion 18/19/20, Windows/macOS/Linux). If yours is elsewhere, set
`FUSION_SCRIPT_LIB` to its full path. `FUSION_HOST` defaults to `localhost`.

## Use with Claude Code

```bash
claude mcp add fusion -s user -- /abs/path/to/venv/bin/python /abs/path/to/fusion-mcp/server.py
```

Optionally pin the library: `-e "FUSION_SCRIPT_LIB=/path/to/fusionscript.dll"`.
MCP servers connect at session start, so a newly-added server appears in the **next**
session.

## Use with any MCP client (e.g. Claude Desktop)

```json
{
  "mcpServers": {
    "fusion": {
      "command": "/abs/path/to/venv/bin/python",
      "args": ["/abs/path/to/fusion-mcp/server.py"]
    }
  }
}
```

## Tools

| Tool | What it does |
|------|--------------|
| `status` | connection + Fusion version + current comp |
| `comp_info` | current comp name/file, render + global range, current time, tool list |
| `list_tools` | tools in the comp (optionally filtered by RegID) |
| `get_tool` | a tool's RegID + current input values |
| `add_tool` | add a tool by RegID (Loader/Saver/OCIOColorSpace/Merge/Blur/Transform/…) |
| `delete_tool` / `rename_tool` | remove / rename a tool |
| `set_input` / `get_input` | set/read an input (strings work for enum/FuID inputs; numbers/bools coerced) |
| `connect_tools` | wire one tool's output into another's input |
| `add_loader` / `add_saver` | convenience: add a Loader/Saver at a path |
| `set_current_time` | move the playhead |
| `render` | render the whole range, or a start/end range |
| `save_comp` / `open_comp` | save / open a `.comp` |

All mutations are wrapped in `Lock`/`StartUndo`…`EndUndo`/`Unlock` — each is a single
undo step and never leaves the comp locked.

## Extending

Add an `@mcp.tool()` function in `server.py`. The Fusion object model is reachable via
`_fusion()` (app), `_comp()` (current comp) and `_tool(name)` (a tool by name). See
Blackmagic's Fusion scripting docs for RegIDs, input IDs (`INPS_ID`) and attributes
(`GetAttrs()`).

## Notes

- It drives your **live** Fusion session; mutations affect the open comp (undoable).
  It never launches or kills Fusion.
- Single-file, no dependencies beyond `mcp`.
- Custom fuses register with a `Fuse.` namespace prefix in Fusion's registry
  (e.g. `Fuse.PSN_Threshold`); pass the prefixed ID to `add_tool`.

## License

MIT — see [LICENSE](LICENSE).
