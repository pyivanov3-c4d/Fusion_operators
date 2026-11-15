-- PSN_ColorNodes 1.0
-- Colour node tiles by category so a big flow reads at a glance.
-- Runs on the selected nodes; with nothing selected it colours the whole comp.
--
-- Fusion only offers one colour per node (the strip under the tile) and snaps it
-- to a fixed palette, so the values below are exact palette entries: nothing is
-- mapped to a different swatch than the one intended.
--
-- Install: %APPDATA%\Blackmagic Design\Fusion\Scripts\Comp\PSN_ColorNodes.lua
-- Menu:    Scripts -> Comp -> PSN_ColorNodes

local comp = Fusion().CurrentComp
if comp == nil then return end

local function C(r, g, b)
	return { R = r, G = g, B = b, A = 1.0 }
end

-- Fusion's tile palette, measured on 20.0.0.50.
local PAL = {
	io        = C(0.776, 0.627, 0.467), -- tan
	generate  = C(0.922, 0.431, 0.000), -- orange
	composite = C(0.475, 0.659, 0.816), -- sky
	mask      = C(0.373, 0.600, 0.125), -- green
	channel   = C(0.267, 0.561, 0.396), -- sea green
	filter    = C(0.000, 0.596, 0.600), -- teal
	transform = C(0.082, 0.384, 0.518), -- steel blue
	color     = C(0.584, 0.294, 0.804), -- violet
	three_d   = C(0.624, 0.776, 0.082), -- lime
	tracking  = C(0.914, 0.549, 0.710), -- pink
	other     = C(0.725, 0.690, 0.592), -- beige
}

-- Our own tools by registry ID (the "Fuse." prefix is dropped before lookup), so
-- a PSN operator never depends on a keyword guess.
local PSN = {
	PSN_BrightnessContrast = "color",
	PSN_ColorProfileCreate = "color",
	PSN_ColorProfileMatch  = "color",
	PSN_DotProduct         = "mask",
	PSN_Explode            = "channel",
	PSN_FigmaAdjustment    = "color",
	PSN_GradientMap        = "color",
	PSN_GradientMapExt     = "color",
	PSN_LUT                = "color",
	PSN_PhotoFilter        = "color",
	PSN_SelectiveColor     = "color",
	PSN_SplineArrange      = "transform",
	PSN_Threshold          = "color",
	PSN_Vibrance           = "color",
	PSN_CleanSharp         = "filter",
}

-- Keyword rules for everything else, checked in order: the first word found in
-- the registry ID wins, so put the narrow buckets first.
local RULES = {
	{ "io", { "loader", "saver", "mediain", "mediaout", "createreel" } },
	{ "generate", { "background", "text", "plasma", "noise", "mandelbrot", "generator", "fractal" } },
	{ "composite", { "merge", "dissolve", "addmix", "composite", "stack" } },
	{ "mask", { "mask", "matte", "polygon", "ellipse", "rectangle", "bspline", "paint", "wand", "keyer" } },
	{ "channel", { "explode", "channel", "setalpha", "copyalpha", "alpha" } },
	{ "filter", { "blur", "glow", "sharpen", "defocus", "soft", "noise" } },
	{ "transform", { "transform", "move", "resize", "rotate", "crop", "spline", "arrange", "cornerpin", "stabilise", "stabilize" } },
	{ "color", { "colour", "color", "hue", "curve", "level", "bright", "contrast", "gain", "gamma",
		"lut", "satur", "vibrance", "threshold", "posterize", "replace", "gradientmap", "figma", "photofilter" } },
	{ "three_d", { "3d", "renderer", "shape", "displace" } },
	{ "tracking", { "track", "planar", "analys" } },
}

-- Annotation tools keep whatever colour the artist gave them.
local SKIP = { Note = true, Underlay = true, GroupOperator = true }

local function classify(regid)
	local id = regid:gsub("^Fuse%.", "")
	if PSN[id] then return PSN[id] end
	local low = id:lower()
	for _, rule in ipairs(RULES) do
		for _, word in ipairs(rule[2]) do
			if low:find(word, 1, true) then return rule[1] end
		end
	end
	return "other"
end

local targets = {}
for _, t in pairs(comp:GetToolList(true)) do targets[#targets + 1] = t end
local selectionOnly = #targets > 0
if not selectionOnly then
	for _, t in pairs(comp:GetToolList(false)) do targets[#targets + 1] = t end
end
if #targets == 0 then
	print("PSN_ColorNodes: the comp has no nodes to colour")
	return
end

local counts, unclassified, painted = {}, {}, 0

comp:Lock()
comp:StartUndo("Colour nodes by category")
local ok, err = pcall(function()
	for _, t in pairs(targets) do
		local attrs = t:GetAttrs()
		local id = tostring(attrs.TOOLS_RegID or "")
		local name = tostring(attrs.TOOLS_Name or "?")
		if id ~= "" and not SKIP[id] then
			local bucket = classify(id)
			local c = PAL[bucket]
			t.TileColor = { R = c.R, G = c.G, B = c.B, A = 1.0 }
			painted = painted + 1
			counts[bucket] = (counts[bucket] or 0) + 1
			if bucket == "other" then
				unclassified[id] = (unclassified[id] or 0) + 1
			end
		end
	end
end)
comp:EndUndo(ok)
comp:Unlock()

if not ok then
	print("PSN_ColorNodes: " .. tostring(err))
	return
end

local order = { "io", "generate", "composite", "mask", "channel", "filter", "transform", "color", "three_d", "tracking", "other" }
local parts = {}
for _, key in ipairs(order) do
	if counts[key] then parts[#parts + 1] = key .. " " .. counts[key] end
end
print(string.format("PSN_ColorNodes: %d node(s)%s -> %s",
	painted, selectionOnly and " (selection)" or "", table.concat(parts, ", ")))

if next(unclassified) then
	local list = {}
	for id, n in pairs(unclassified) do list[#list + 1] = id .. (n > 1 and (" x" .. n) or "") end
	table.sort(list)
	print("  unclassified (beige): " .. table.concat(list, ", "))
end
