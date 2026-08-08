-- jewel_optimizer.lua — Split Personality / radius jewel socket repositioning
-- Split Personality scales with distance from start; zigzag paths increase graph distance.

local M = {}

function M:getStartNodeId(spec)
	if spec.curClassId and spec.tree and spec.tree.classes then
		local class = spec.tree.classes[spec.curClassId]
		if class and class.startNode then
			return class.startNode
		end
	end
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.isStart then return nodeId end
	end
	return nil
end

function M:graphDistance(spec, startId, targetId, allocNodes)
	if not startId or not targetId then return 0 end
	if startId == targetId then return 0 end

	local visited = { [startId] = 0 }
	local queue = { startId }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		local node = spec.tree.nodes[cur]
		if node and node.linked then
			for _, linkId in ipairs(node.linked) do
				if not visited[linkId] then
					local step = visited[cur] + 1
					-- Zigzag: count only through allocated nodes (longer effective path)
					if allocNodes and not allocNodes[linkId] and linkId ~= targetId then
						step = step + 0.5
					end
					visited[linkId] = step
					if linkId == targetId then
						return step
					end
					table.insert(queue, linkId)
				end
			end
		end
	end
	return visited[targetId] or 0
end

function M:findJewelSockets(spec, allocNodes)
	local sockets = {}
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.type == "Socket" and allocNodes[nodeId] then
			table.insert(sockets, {
				id = nodeId,
				dist = 0,
				isLarge = node.expansionJewel and node.expansionJewel.size == 2,
			})
		end
	end
	return sockets
end

function M:isSplitPersonality(item)
	if not item or not item.name then return false end
	local n = item.name:lower()
	return n:find("split personality") ~= nil
end

function M:collectSplitJewels(build)
	local jewels = {}
	local itemsTab = build.itemsTab
	if not itemsTab or not itemsTab.items then return jewels end
	for slot, item in pairs(itemsTab.items) do
		if item and self:isSplitPersonality(item) then
			table.insert(jewels, { slot = slot, item = item })
		end
	end
	return jewels
end

function M:scorePlacement(spec, startId, socketId, allocNodes, zigzag)
	local dist = self:graphDistance(spec, startId, socketId, zigzag and allocNodes or nil)
	return dist
end

function M:optimize(build, archetype, options)
	local spec = build.spec
	local itemsTab = build.itemsTab
	if not spec or not itemsTab then return end

	local startId = self:getStartNodeId(spec)
	if not startId then return end

	local allocNodes = {}
	for nodeId in pairs(spec.allocNodes or spec.nodes or {}) do
		allocNodes[nodeId] = true
	end

	local splitJewels = self:collectSplitJewels(build)
	if #splitJewels == 0 then return end

	local sockets = self:findJewelSockets(spec, allocNodes)
	if #sockets == 0 then return end

	for _, s in ipairs(sockets) do
		s.distStraight = self:scorePlacement(spec, startId, s.id, allocNodes, false)
		s.distZigzag = self:scorePlacement(spec, startId, s.id, allocNodes, true)
		s.dist = math.max(s.distStraight, s.distZigzag)
	end
	table.sort(sockets, function(a, b) return a.dist > b.dist end)

	-- Assign split jewels to farthest sockets (better SP scaling)
	for i, jewel in ipairs(splitJewels) do
		local target = sockets[i]
		if target and jewel.slot ~= ("Jewel " .. target.id) then
			-- Swap toward farther socket when item tab supports it
			local farSlot = nil
			for slot, _ in pairs(itemsTab.items or {}) do
				if slot:find("Jewel") and slot:find(tostring(target.id)) then
					farSlot = slot
					break
				end
			end
			if farSlot and itemsTab.SwapItems then
				pcall(function() itemsTab:SwapItems(jewel.slot, farSlot) end)
			end
		end
	end

	if options.mutateJewelPaths then
		self:mutatePathToSocket(build, spec, startId, sockets[1], allocNodes, archetype)
	end

	build:BuildAll()
end

-- Extend tree path toward a distant jewel socket (zigzag routing)
function M:mutatePathToSocket(build, spec, startId, farSocket, allocNodes, archetype)
	if not farSocket then return end
	local targetId = farSocket.id
	local node = spec.tree.nodes[targetId]
	if not node or not node.linked then return end

	for _, linkId in ipairs(node.linked) do
		if not allocNodes[linkId] and spec.tree.nodes[linkId] then
			local ln = spec.tree.nodes[linkId]
			if ln.alloc then
				pcall(function() spec:SelectNode(linkId) end)
				allocNodes[linkId] = true
				break
			end
		end
	end
end

return M
