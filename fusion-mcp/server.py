"""Fusion Studio MCP server.

Drives a *running* Fusion Studio instance via its scripting bridge (fusionscript.dll),
exposing tools to inspect, build, modify and render comps.

Prereqs:
  - Fusion Studio running (scripting is on by default in Studio).
  - FUSION_SCRIPT_LIB env (optional) -> path to fusionscript.dll
    (default: C:\\Program Files\\Blackmagic Design\\Fusion 20\\fusionscript.dll)
  - FUSION_HOST env (optional, default 'localhost').
"""
import os, contextlib, importlib.machinery, importlib.util
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("fusion")
_FU = None

# Common fusionscript library locations, newest first. Override with FUSION_SCRIPT_LIB.
_LIB_CANDIDATES = [
    r"C:\Program Files\Blackmagic Design\Fusion 20\fusionscript.dll",
    r"C:\Program Files\Blackmagic Design\Fusion 19\fusionscript.dll",
    r"C:\Program Files\Blackmagic Design\Fusion 18\fusionscript.dll",
    r"C:\Program Files\Blackmagic Design\Fusion Render Node 20\fusionscript.dll",
    "/Applications/Blackmagic Fusion 20/Fusion.app/Contents/MacOS/fusionscript.so",
    "/Applications/Blackmagic Fusion 19/Fusion.app/Contents/MacOS/fusionscript.so",
    "/Applications/Blackmagic Fusion 18/Fusion.app/Contents/MacOS/fusionscript.so",
    "/opt/BlackmagicDesign/Fusion20/fusionscript.so",
    "/opt/BlackmagicDesign/Fusion19/fusionscript.so",
]


def _find_lib():
    lib = os.environ.get("FUSION_SCRIPT_LIB")
    if lib:
        return lib
    for c in _LIB_CANDIDATES:
        if os.path.exists(c):
            return c
    raise RuntimeError(
        "fusionscript library not found. Set FUSION_SCRIPT_LIB to the path of "
        "fusionscript.dll (Windows) / fusionscript.so (macOS/Linux)."
    )


def _fusion():
    """Connect (and cache) the Fusion app object, re-validating a stale handle."""
    global _FU
    if _FU is not None:
        try:
            _FU.GetVersion(); return _FU
        except Exception:
            _FU = None
    lib = _find_lib()
    loader = importlib.machinery.ExtensionFileLoader("fusionscript", lib)
    spec = importlib.util.spec_from_loader("fusionscript", loader)
    fs = importlib.util.module_from_spec(spec)
    loader.exec_module(fs)
    fu = fs.scriptapp("Fusion", os.environ.get("FUSION_HOST", "localhost"))
    if not fu:
        raise RuntimeError("Cannot connect to Fusion Studio. Is it running with scripting enabled?")
    _FU = fu
    return fu


def _comp():
    c = _fusion().GetCurrentComp()
    if not c:
        raise RuntimeError("No composition open in Fusion.")
    return c


def _tool(name):
    t = _comp().FindTool(name)
    if not t:
        raise RuntimeError("No tool named '%s' in the comp." % name)
    return t


def _summ(t):
    a = t.GetAttrs()
    return {"name": a.get("TOOLS_Name"), "regid": a.get("TOOLS_RegID")}


@contextlib.contextmanager
def _undo(c, name):
    c.Lock(); c.StartUndo(name)
    try:
        yield
    finally:
        c.EndUndo(True); c.Unlock()


def _coerce(value):
    """Turn an MCP string arg into the right Fusion value (number / bool / string)."""
    if isinstance(value, (int, float)):
        return value
    s = str(value).strip()
    low = s.lower()
    if low in ("true", "false"):
        return 1 if low == "true" else 0
    try:
        f = float(s)
        return int(f) if f.is_integer() else f
    except ValueError:
        return s


def _jsonify(v):
    if hasattr(v, "GetAttrs"):
        return "<%s>" % (v.GetAttrs().get("TOOLS_Name") or type(v).__name__)
    if isinstance(v, dict):
        return {str(k): _jsonify(x) for k, x in v.items()}
    return v


# ---------------- read ----------------
@mcp.tool()
def status() -> dict:
    """Fusion connection status: version + current comp."""
    fu = _fusion(); v = fu.GetVersion(); c = fu.GetCurrentComp()
    return {"connected": True,
            "version": "%s.%s.%s.%s" % (v.get(1), v.get(2), v.get(3), v.get(4)),
            "app": v.get("App"),
            "comp": c.GetAttrs("COMPS_Name") if c else None,
            "comp_file": c.GetAttrs("COMPS_FileName") if c else None}


@mcp.tool()
def comp_info() -> dict:
    """Current comp: name, file, render range, current time, and the tool list."""
    c = _comp(); a = c.GetAttrs()
    return {"name": a.get("COMPS_Name"), "file": a.get("COMPS_FileName"),
            "render_start": a.get("COMPN_RenderStart"), "render_end": a.get("COMPN_RenderEnd"),
            "global_start": a.get("COMPN_GlobalStart"), "global_end": a.get("COMPN_GlobalEnd"),
            "current_time": c.CurrentTime,
            "tools": [_summ(t) for t in c.GetToolList(False).values()]}


@mcp.tool()
def list_tools(regid: str = "") -> list:
    """List tools in the comp, optionally filtered by RegID (e.g. 'Loader', 'OCIOColorSpace', 'Merge')."""
    c = _comp()
    tl = c.GetToolList(False, regid) if regid else c.GetToolList(False)
    return [_summ(t) for t in tl.values()]


@mcp.tool()
def get_tool(name: str) -> dict:
    """A tool's RegID + its current input values (best-effort, at current time)."""
    t = _tool(name); c = _comp(); tm = c.CurrentTime
    inputs = {}
    for inp in (t.GetInputList() or {}).values():
        iid = inp.GetAttrs("INPS_ID")
        try:
            inputs[iid] = _jsonify(t.GetInput(iid, tm))
        except Exception:
            pass
    return {**_summ(t), "inputs": inputs}


# ---------------- build / modify ----------------
@mcp.tool()
def add_tool(regid: str, name: str = "", x: int = -32768, y: int = -32768) -> dict:
    """Add a tool by RegID (Loader, Saver, OCIOColorSpace, Merge, Blur, Transform, ...). Optionally rename + position on the flow."""
    c = _comp()
    with _undo(c, "add " + regid):
        t = c.AddTool(regid, x, y)
        if not t:
            raise RuntimeError("AddTool failed for RegID '%s'." % regid)
        if name:
            t.SetAttrs({"TOOLS_Name": name})
    return _summ(t)


@mcp.tool()
def delete_tool(name: str) -> dict:
    """Delete a tool by name."""
    t = _tool(name); c = _comp()
    with _undo(c, "delete " + name):
        t.Delete()
    return {"deleted": name}


@mcp.tool()
def rename_tool(name: str, new_name: str) -> dict:
    """Rename a tool."""
    t = _tool(name); c = _comp()
    with _undo(c, "rename"):
        t.SetAttrs({"TOOLS_Name": new_name})
    return {"renamed": "%s -> %s" % (name, new_name)}


@mcp.tool()
def set_input(tool: str, input: str, value: str, frame: str = "") -> dict:
    """Set a tool input at the current frame (or a given frame). String values work for enum/FuID inputs (e.g. OCIO SourceSpace='ACEScg'); numbers/bools are auto-coerced."""
    t = _tool(tool); c = _comp()
    tm = c.CurrentTime if frame == "" else float(frame)
    val = _coerce(value)
    with _undo(c, "set %s.%s" % (tool, input)):
        t.SetInput(input, val, tm)
    return {"tool": tool, "input": input, "value": _jsonify(t.GetInput(input, tm))}


@mcp.tool()
def get_input(tool: str, input: str) -> dict:
    """Read a single tool input value at the current frame."""
    t = _tool(tool); c = _comp()
    return {"tool": tool, "input": input, "value": _jsonify(t.GetInput(input, c.CurrentTime))}


@mcp.tool()
def connect_tools(from_tool: str, to_tool: str, to_input: str = "Input") -> dict:
    """Wire from_tool's primary output into to_tool's named input (default 'Input'; e.g. 'Background'/'Foreground' on a Merge)."""
    src = _tool(from_tool); dst = _tool(to_tool); c = _comp()
    with _undo(c, "connect"):
        dst.ConnectInput(to_input, src)
    return {"connected": "%s.Output -> %s.%s" % (from_tool, to_tool, to_input)}


@mcp.tool()
def add_loader(path: str, name: str = "") -> dict:
    """Add a Loader reading the given image/sequence path (point it at the first frame of a sequence)."""
    c = _comp()
    with _undo(c, "add loader"):
        t = c.AddTool("Loader")
        if name:
            t.SetAttrs({"TOOLS_Name": name})
        t.Clip[c.CurrentTime] = path
    return {**_summ(t), "clip": path}


@mcp.tool()
def add_saver(path: str, name: str = "") -> dict:
    """Add a Saver writing to the given path."""
    c = _comp()
    with _undo(c, "add saver"):
        t = c.AddTool("Saver")
        if name:
            t.SetAttrs({"TOOLS_Name": name})
        t.Clip[c.CurrentTime] = path
    return {**_summ(t), "clip": path}


# ---------------- comp / time / render ----------------
@mcp.tool()
def set_current_time(frame: int) -> dict:
    """Move the comp playhead to a frame."""
    c = _comp(); c.CurrentTime = frame
    return {"current_time": c.CurrentTime}


@mcp.tool()
def render(start: str = "", end: str = "", wait: bool = True) -> dict:
    """Render the comp — whole render range, or a frame range if start/end given."""
    c = _comp()
    args = {"Wait": wait}
    if start != "":
        args["Start"] = int(start)
    if end != "":
        args["End"] = int(end)
    ok = c.Render(args)
    return {"rendered": bool(ok), "start": start or "range", "end": end or "range"}


@mcp.tool()
def save_comp(path: str = "") -> dict:
    """Save the comp (to its current file, or to a given path)."""
    c = _comp()
    ok = c.Save(path) if path else c.Save()
    return {"saved": bool(ok), "file": c.GetAttrs("COMPS_FileName")}


@mcp.tool()
def open_comp(path: str) -> dict:
    """Open a .comp file in Fusion and make it current."""
    c = _fusion().LoadComp(path)
    return {"opened": bool(c), "comp": c.GetAttrs("COMPS_Name") if c else None}


if __name__ == "__main__":
    mcp.run()
