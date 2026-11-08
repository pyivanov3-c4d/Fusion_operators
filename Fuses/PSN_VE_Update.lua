--[[--
PSN_VE_Update : version check / self-update helper for the PSN_VE_NeuralRender operator.

Installed alongside the fuse. The fuse's "Check for updates" button and the
Scripts menu both call this module.

Source of truth = a folder containing:
  VERSION                    e.g. "2.1"
  PSN_VE_NeuralRender.fuse
  PSN_VE_Update.lua
  PSN_VE_Bake.lua

M.check(sourceDir) -> version, status string            (no side effects)
M.install(sourceDir, fuseDir, silent) -> status string  (copies newer files)
M.alert(title, text)                                    (Windows message box)
--]]--

local M = {}

M.VERSION = "2.1"

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local d = f:read("*a")
	f:close()
	return d
end

local function copyFile(from, to)
	local data = readAll(from)
	if not data then return false end
	local f = io.open(to, "wb")
	if not f then return false end
	f:write(data)
	f:close()
	return true
end

local function trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parts(v)
	local t = {}
	for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
	return t
end

-- -1 = source older, 0 = equal, 1 = source newer
function M.compare(sourceVersion, installedVersion)
	local a, b = parts(sourceVersion), parts(installedVersion)
	for i = 1, math.max(#a, #b) do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then return (x > y) and 1 or -1 end
	end
	return 0
end

function M.alert(title, text)
	local tmp = (os.getenv("TEMP") or ".") .. "\\psn_ve_alert.ps1"
	local f = io.open(tmp, "wb")
	if not f then return end
	f:write("Add-Type -AssemblyName PresentationFramework\r\n")
	f:write("[System.Windows.MessageBox]::Show(@'\r\n")
	f:write(tostring(text):gsub("\r", ""))
	f:write("\r\n'@, '")
	f:write(tostring(title):gsub("'", "''"))
	f:write("') | Out-Null\r\n")
	f:close()
	os.execute('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. tmp .. '"')
end

-- returns installedVersion, sourceVersion, comparison, readable status
function M.check(sourceDir)
	local installed = M.VERSION
	local raw = readAll(sourceDir .. "\\VERSION")
	if not raw then
		return installed, nil, nil, "update source not found: " .. tostring(sourceDir)
	end
	local source = trim(raw)
	local cmp = M.compare(source, installed)
	local text
	if cmp > 0 then
		text = string.format("update available: source %s, installed %s", source, installed)
	elseif cmp == 0 then
		text = string.format("up to date (%s)", installed)
	else
		text = string.format("installed %s is newer than source %s", installed, source)
	end
	return installed, source, cmp, text
end

-- copies newer files next to the fuse; returns status string
function M.install(sourceDir, fuseDir, silent)
	local installed, source, cmp, text = M.check(sourceDir)
	if not source then
		if not silent then M.alert("PSN VE update", text) end
		return "error", text
	end
	if cmp <= 0 then
		if not silent then M.alert("PSN VE update", text) end
		return (cmp == 0) and "uptodate" or "newer-local", text
	end

	local profile = fuseDir:gsub("\\Fuses$", "")
	local bakeTarget = profile .. "\\Scripts\\Comp\\PSN_VE_Bake.lua"

	local okFuse = copyFile(sourceDir .. "\\PSN_VE_NeuralRender.fuse", fuseDir .. "\\PSN_VE_NeuralRender.fuse")
	local okMod = copyFile(sourceDir .. "\\PSN_VE_Update.lua", fuseDir .. "\\PSN_VE_Update.lua")
	local okBake = copyFile(sourceDir .. "\\PSN_VE_Bake.lua", bakeTarget)
	copyFile(sourceDir .. "\\VERSION", fuseDir .. "\\VERSION")

	local problems = {}
	if not okFuse then problems[#problems + 1] = "fuse" end
	if not okMod then problems[#problems + 1] = "updater" end
	if not okBake then problems[#problems + 1] = "bake script" end

	if #problems > 0 then
		local msg = "update failed for: " .. table.concat(problems, ", ") .. "\nfiles come from: " .. sourceDir
		if not silent then M.alert("PSN VE update", msg) end
		return "error", msg
	end

	local msg = string.format(
		"Updated from %s to %s.\n\nRestart Fusion to load the new operator version.\nFiles: fuse, updater, bake script.",
		installed, source)
	if not silent then M.alert("PSN VE update", msg) end
	return "updated", msg
end

return M
