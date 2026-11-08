-- PSN_VE_Refresh.lua : poke a PSN_VE_NeuralRender node so Fusion re-evaluates it
-- and the viewer shows a freshly baked frame. Run by the background baker.
--
-- Usage: fuscript.exe -l lua PSN_VE_Refresh.lua <node name>

local nodeName = ... or ""

local c = Fusion().CurrentComp
if not c then
	print("PSN_VE_Refresh: no comp")
	return
end

for _, t in pairs(c:GetToolList(false, "Fuse.PSN_VE_NeuralRender")) do
	local okA, attrs = pcall(function() return t:GetAttrs() end)
	local name = okA and attrs and attrs.TOOLS_Name or ""
	if nodeName == "" or name == nodeName then
		local ok, cur = pcall(function() return t:GetInput("Refresh", 1) end)
		if ok then
			local tval = c.CurrentTime
			pcall(function() t:SetInput("Refresh", (cur == 1) and 0 or 1, tval) end)
		end
		break
	end
end
