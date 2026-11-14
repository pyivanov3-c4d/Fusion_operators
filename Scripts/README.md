# Scripts

Companion Fusion scripts — **not** fuses. A `.lua` here is a comp script: it runs from
Fusion's `Script` menu (or a hotkey) and builds/wires nodes, instead of registering a new
tool the way a `.fuse` does.

Install path mirrors the folder tree: `Scripts/Comp/` → `%APPDATA%\Blackmagic Design\Fusion\Scripts\Comp\`.
Restart is not needed; Fusion picks comp scripts up when the menu is opened.

| File | Menu entry | What it does |
|---|---|---|
| `Comp/Null.lua` | `Scripts → Comp → Null` | Inserts the small square `Null` (PipeRouter) after the selected node, painted yellow and spliced into the chain (`selected → Null → what followed`). Bound to a hotkey via `View → Customize Hotkeys`; `Ctrl+Alt+N` is the one used here. |

Why a script: Fusion draws every fuse as its standard long tile, so the compact square
marker can only be a PipeRouter — and a PipeRouter is inserted, not registered.
