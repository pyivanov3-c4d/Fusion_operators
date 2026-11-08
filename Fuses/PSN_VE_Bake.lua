--[[--
PSN_VE_Bake : bake a frame range through Visual Enhancer (DLSS 5 Neural Rendering).

Select a PSN_VE_NeuralRender node, then run Scripts > PSN_VE_Bake.

1. renders the node's input over the comp render range to 16-bit TIFF frames
2. runs VE_CLI once over the whole folder (about 0.42 s/frame after model load)
3. points the node's "Baked result folder" at the results, so the operator serves
   the cached frames instantly and you can scrub the shot in motion.

Install: %APPDATA%\Blackmagic Design\Fusion\Scripts\Comp\PSN_VE_Bake.lua
--]]--

local fusion = Fusion()
local comp = fusion.CurrentComp
if not comp then print("PSN_VE_Bake: no comp") return end

local tool = comp.ActiveTool
if not tool then print("PSN_VE_Bake: select a PSN_VE_NeuralRender node first") return end

local okid, attrs = pcall(function() return tool:GetAttrs() end)
local regid = okid and attrs and attrs.TOOLS_RegID or ""
if regid ~= "Fuse.PSN_VE_NeuralRender" then
	print("PSN_VE_Bake: selected tool is '" .. tostring(regid) .. "', expected Fuse.PSN_VE_NeuralRender")
	return
end

local t = comp.CurrentTime

local function val(id, default)
	local ok, v = pcall(function() return tool:GetInput(id, 1) end)
	if not ok or v == nil then return default end
	return v
end

local engine = val("EnginePath", "")
local cacheDir = val("CacheDir", "")
local gpu = val("GPU", "auto")
local srgb = val("SRGB", 1) > 0.5
local algo = math.floor(val("Algo", 0) + 0.5)
if algo ~= 0 then
	print("PSN_VE_Bake: bake is implemented for Neural Rendering only (Algorithm = Neural Rendering)")
	return
end
if engine == "" or cacheDir == "" then
	print("PSN_VE_Bake: set Engine and Cache folder on the node first")
	return
end

local startFrame = comp:GetPrefs("Comp.RenderStart")
local endFrame = comp:GetPrefs("Comp.RenderEnd")
if not startFrame or not endFrame or endFrame < startFrame then
	print("PSN_VE_Bake: comp render range is invalid")
	return
end

local bakeRoot = cacheDir .. "\\bake"
local inDir = bakeRoot .. "\\in"
local outDir = bakeRoot .. "\\out"
local collectDir = bakeRoot .. "\\collect"

local function sh(cmd) return os.execute(cmd) end
sh('cmd /c if exist "' .. inDir .. '" rmdir /s /q "' .. inDir .. '"')
sh('cmd /c if exist "' .. outDir .. '" rmdir /s /q "' .. outDir .. '"')
sh('cmd /c if not exist "' .. inDir .. '" mkdir "' .. inDir .. '"')
sh('cmd /c if not exist "' .. outDir .. '" mkdir "' .. outDir .. '"')
sh('cmd /c if not exist "' .. collectDir .. '" mkdir "' .. collectDir .. '"')

-- ---------------------------------------------------------------- preset

local styleIdx = math.floor(val("Style", 0) + 0.5)
local style = ({ "Style 0", "Style 1", "Style 2" })[math.max(0, math.min(2, styleIdx)) + 1]
local sharpen = val("Sharpen", 0) > 0.5
local grain = val("Grain", 0) > 0.5

local stages = { "neural_model" }
if sharpen then stages[#stages + 1] = "cas_sharpening" end
if grain then stages[#stages + 1] = "grain" end

local en = {}
for i = 1, #stages do en[i] = '"' .. stages[i] .. '"' end

local settings = {
	string.format('"image_stage_order": ["neural_model","scale_method","dlss_super_resolution","dlss_ray_reconstruction","super_resolution","reshade","coloring","cas_sharpening","grain"]'),
	string.format('"image_enabled_stages": [%s]', table.concat(en, ",")),
	string.format('"nr_style": "%s"', style),
	string.format('"nr_intensity": %.4f', val("Intensity", 1)),
	string.format('"nr_passes": %d', math.floor(val("Passes", 1) + 0.5)),
	string.format('"local_tone_strength": %.4f', val("LocalTone", 1)),
	string.format('"local_structure_strength": %.4f', val("LocalStructure", 1)),
	string.format('"skin_structure_strength": %.4f', val("SkinStructure", 1)),
	string.format('"automatic_mask": %s', val("AutoMask", 0) > 0.5 and "true" or "false"),
	'"image_format": "TIFF"',
	'"image_bit_depth": 16',
}
if sharpen then
	settings[#settings + 1] = '"sharpening_method": "AMD CAS"'
	settings[#settings + 1] = string.format('"cas_sharpness": %d', math.floor(val("SharpenAmount", 50) + 0.5))
end
if grain then
	settings[#settings + 1] = string.format('"grain_amount": %d', math.floor(val("GrainAmount", 20) + 0.5))
end

local preset = '{\n  "format": "dlss5-visual-enhancer-settings-preset",\n'
	.. '  "schema_version": 41,\n  "name": "PSN VE Bake",\n'
	.. '  "settings": {\n    ' .. table.concat(settings, ",\n    ") .. "\n  }\n}\n"

local presetPath = bakeRoot .. "\\bake_preset.json"
local pf = assert(io.open(presetPath, "wb"))
pf:write(preset)
pf:close()

-- ---------------------------------------------------------------- collect pass

print(string.format("PSN_VE_Bake: rendering frames %d-%d for the engine...", startFrame, endFrame))

-- silence other savers so comp:Render only produces our collection pass
local others, restore = comp:GetToolList(false, "Saver"), {}
for _, s in pairs(others) do
	local ok, pt = pcall(function() return s.PassThrough end)
	if ok then
		restore[s] = pt
		pcall(function() s.PassThrough = true end)
	end
end

local dummy = comp:AddTool("Saver", -32768, -32768)
dummy.Name = "PSN_VE_Collect"
dummy.Input = tool.Output
dummy:SetInput("Clip", collectDir .. "\\dummy.png")

pcall(function() tool:SetInput("Collect", 1) end)
local okRender, errRender = pcall(function() comp:Render(true, startFrame, endFrame, 1) end)
pcall(function() tool:SetInput("Collect", 0) end)

pcall(function() dummy:Delete() end)
for s, pt in pairs(restore) do pcall(function() s.PassThrough = pt end) end

if not okRender then
	print("PSN_VE_Bake: render failed: " .. tostring(errRender))
	return
end

local count = 0
local lfs_ok = pcall(function()
	local p = io.popen('cmd /c dir /b "' .. inDir .. '\\*.tif"')
	for _ in p:lines() do count = count + 1 end
	p:close()
end)
print("PSN_VE_Bake: collected " .. count .. " frames")

-- ---------------------------------------------------------------- engine pass

print("PSN_VE_Bake: running engine (one process for the whole range)...")
local cmd = string.format('"%s" render "%s" -o "%s" --preset "%s" --json --quiet',
	engine, inDir, outDir, presetPath)
if gpu and gpu ~= "" and gpu ~= "auto" then
	cmd = string.format('"%s" render "%s" -o "%s" --preset "%s" --gpu "%s" --json --quiet',
		engine, inDir, outDir, presetPath, gpu)
end

local bat = bakeRoot .. "\\bake.cmd"
local bf = assert(io.open(bat, "wb"))
bf:write("@echo off\r\n" .. cmd .. " 2>&1\r\n")
bf:close()

local t0 = os.clock()
local h = io.popen('cmd /c "' .. bat .. '"')
local result = h and h:read("*a") or ""
if h then h:close() end
print(string.format("PSN_VE_Bake: engine finished in %.1f s", os.clock() - t0))
print("PSN_VE_Bake: " .. (result or ""):gsub("%s+", " "):sub(1, 400))


pcall(function() tool:SetInput("BakeDir", outDir) end)

-- free disk: collected source frames are only needed while the engine runs
local produced = 0
local cnt = io.popen('cmd /c dir /b "' .. outDir .. '\\*.tif*"')
if cnt then
	for _ in cnt:lines() do produced = produced + 1 end
	cnt:close()
end
if produced > 0 then
	sh('cmd /c if exist "' .. inDir .. '" rmdir /s /q "' .. inDir .. '"')
end
print("PSN_VE_Bake: " .. produced .. " result frames on disk")
print("PSN_VE_Bake: done. Node now serves baked frames from " .. outDir)
