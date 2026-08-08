-- cluster_optimizer.lua — SP routing through large cluster jewel sockets

local M = {}

local PRIORITY_NOTABLES = {
	["Added Small Passive Skills grant: 12% increased Fire Damage"] = 10,
	["Added Small Passive Skills grant: 12% increased Burning Damage"] = 10,
	["Added Small Passive Skills grant: 6% increased maximum Mana"] = 9,
	["Added Small Passive Skills grant: 4% increased maximum Life"] = 6,
	["Added Small Passive Skills grant: 15% increased Effect of Non-Damaging Ailments"] = 5,
	["1 Added Passive Skill is Blessed Rebirth"] = 4,
	["1 Added Passive Skill is Unwaveringly Evil"] = 4,
}

function M:findClusterSockets(build, archetype)
	local sockets = {}
	local spec = build.spec
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.type == "Socket" and node.expansionJewel and node.expansionJewel.size == 2 then
			table.insert(sockets, nodeId)
		end
	end
	-- Also tree jewel sockets marked in archetype
	for _, id in ipairs(archetype.clusterSockets or {}) do
		table.insert(sockets, id)
	end
	return sockets
end

function M:scoreClusterJewel(jewelData)
	local score = 0
	if not jewelData or not jewelData.notables then return 0 end
	for _, notable in ipairs(jewelData.notables) do
		score = score + (PRIORITY_NOTABLES[notable] or 1)
	end
	return score
end

function M:optimize(build, archetype, options)
	local itemsTab = build.itemsTab
	if not itemsTab then return end

	local poolPath = MainScriptPath .. "DeepOptimizer/configs/item-pools/" .. (archetype.itemPool or "trade_329") .. ".json"
	local f = io.open(poolPath, "r")
	if not f then return end
	local raw = f:read("*a")
	f:close()
	local json = require("dkjson")
	local ok, pool = pcall(json.decode, raw)
	if not ok or not pool or not pool.clusterJewels then return end

	local bestJewel = nil
	local bestScore = -1
	for _, jewel in ipairs(pool.clusterJewels) do
		local s = self:scoreClusterJewel(jewel)
		if s > bestScore then
			bestScore = s
			bestJewel = jewel
		end
	end

	if not bestJewel then return end

	-- Apply best cluster to first large socket if empty
	local sockets = self:findClusterSockets(build, archetype)
	if #sockets == 0 then return end

	local slotName = "Jewel " .. sockets[1]
	if bestJewel.pobItemText and itemsTab.sockets then
		-- PoB item text import handled by item tab when item exists in pool cache
		for slot, item in pairs(itemsTab.items or {}) do
			if item and item.baseName and item.baseName:match("Large Cluster") then
				itemsTab:ReplaceItem(slot, bestJewel.pobItemText)
				break
			end
		end
	end

	-- Allocate cluster passive nodes from tournament-validated routes
	if bestJewel.allocNodes then
		local spec = build.spec
		for _, nodeId in ipairs(bestJewel.allocNodes) do
			if spec.tree.nodes[nodeId] then
				spec:SelectNode(nodeId)
			end
		end
	end
end

return M
