-- Null: insert Fusion's small square (PipeRouter) after the selected node.
-- The square is named "Null", painted yellow, and spliced into the chain:
-- selected -> Null -> whatever used to follow the selected node.
-- It survives deleting the node it feeds, and passes pixels again as soon as a
-- new tool is connected to its output.
-- Install: %APPDATA%\Blackmagic Design\Fusion\Scripts\Comp\Null.lua

local comp = Fusion().CurrentComp
if comp == nil then return end

local up = comp.ActiveTool
if up == nil then
	print("Null: select the node the Null should follow first")
	return
end

comp:Lock()
comp:StartUndo("Insert Null")
local ok, err = pcall(function()
	local n = comp:AddTool("PipeRouter", -32768, -32768)
	if n == nil then error("PipeRouter could not be created") end
	n:SetAttrs({ TOOLS_Name = "Null" })
	n.TileColor = { R = 1.0, G = 0.85, B = 0.10, A = 1.0 }
	n:ConnectInput("Input", up)

	-- splice: everything that was fed by the selected node now hangs off the Null
	local moved = {}
	for _, t in pairs(comp:GetToolList(false)) do
		if t ~= n and t ~= up then
			for _, inp in pairs(t:GetInputList()) do
				local okc, con = pcall(function() return inp:GetConnectedOutput() end)
				if okc and con ~= nil then
					local okp, owner = pcall(function() return con:GetTool() end)
					if okp and owner == up then
						t:ConnectInput(inp.ID, n)
						moved[#moved + 1] = t.Name .. "." .. inp.ID
					end
				end
			end
		end
	end
	print("Null inserted after " .. up.Name .. (#moved > 0 and (" (spliced before " .. table.concat(moved, ", ") .. ")") or " (nothing followed it)"))
end)
comp:EndUndo(true)
comp:Unlock()

if not ok then print("Null: " .. tostring(err)) end
