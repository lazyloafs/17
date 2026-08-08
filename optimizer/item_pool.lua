-- item_pool.lua — Apply non-self-owned (trade league) item templates to build slots

local M = {}

function M:loadPool(name)
	local path = MainScriptPath .. "DeepOptimizer/configs/item-pools/" .. name .. ".json"
	local f = io.open(path, "r")
	if not f then return nil end
	local raw = f:read("*a")
	f:close()
	local json = require("dkjson")
	local ok, data = pcall(json.decode, raw)
	return ok and data or nil
end

function M:apply(build, poolName)
	local pool = self:loadPool(poolName)
	if not pool or not pool.slots then return end

	local itemsTab = build.itemsTab
	if not itemsTab then return end

	for slot, entry in pairs(pool.slots) do
		if entry.pobItemText and itemsTab.sockets and itemsTab.sockets[slot] then
			local ok = pcall(function()
				itemsTab:CreateItemFromRaw(entry.pobItemText, slot)
			end)
			if not ok and itemsTab.controls and itemsTab.controls[slot] then
				-- Fallback: set raw if CreateItemFromRaw unavailable in this PoB version
				itemsTab:SetSlot(slot, entry.pobItemText)
			end
		end
	end

	-- Apply flask setup
	if pool.flasks then
		for i, flask in ipairs(pool.flasks) do
			local slot = "Flask " .. i
			if flask.pobItemText then
				pcall(function() itemsTab:CreateItemFromRaw(flask.pobItemText, slot) end)
			end
		end
	end

	build:BuildAll()
end

return M
