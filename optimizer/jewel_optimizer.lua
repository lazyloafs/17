-- jewel_optimizer.lua — Split Personality socket repositioning
-- PoE: "25% increased effect per Allocated Passive Skill between it and your
-- Class' starting location". Longer allocated (zigzag) paths beat shortest paths.

local M = {}

function M:getStartNodeId(spec)
	if spec.curClassId and spec.tree and spec.tree.classes then
		local class = spec.tree.classes[spec.curClassId]
		if class and class.startNodeId then return class.startNodeId end
		if class and class.startNode then return class.startNode end
	end
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.isStart then return nodeId end
	end
	return nil
end

-- Shortest path length through ANY tree edges (straight geographic distance)
function M:straightDistance(spec, startId, targetId)
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
					visited[linkId] = visited[cur] + 1
					if linkId == targetId then return visited[linkId] end
					table.insert(queue, linkId)
				end
			end
		end
	end
	return 0
end

-- Allocated-path length (exact Split Personality scaler)
function M:allocatedPathLength(spec, startId, targetId, allocNodes)
	if not startId or not targetId or not allocNodes[targetId] then return 0 end
	local visited = { [startId] = 0 }
	local queue = { startId }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		local node = spec.tree.nodes[cur]
		if node and node.linked then
			for _, linkId in ipairs(node.linked) do
				if not visited[linkId] and allocNodes[linkId] then
					visited[linkId] = visited[cur] + 1
					if linkId == targetId then return visited[linkId] end
					table.insert(queue, linkId)
				end
			end
		end
	end
	return 0
end

-- Potential zigzag score: allocated path if we also allocate a longer detour corridor
-- Approximated as max(allocatedPath, straightDistance) — zigzag wins when tree snakes.
function M:scoreSocket(spec, startId, socketId, allocNodes, preferZigzag)
	local straight = self:straightDistance(spec, startId, socketId)
	local allocated = self:allocatedPathLength(spec, startId, socketId, allocNodes)
	local zigzag = math.max(allocated, straight)
	if preferZigzag then
		-- Reward paths that are longer than the straight line (true zigzag)
		if allocated > straight then
			zigzag = allocated + (allocated - straight) * 0.25
		end
	end
	return {
		straight = straight,
		allocated = allocated,
		zigzag = zigzag,
		best = math.max(allocated, zigzag),
	}
end

function M:findJewelSockets(spec, allocNodes)
	local sockets = {}
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.type == "Socket" and allocNodes[nodeId] then
			table.insert(sockets, {
				id = nodeId,
				isLarge = node.expansionJewel and node.expansionJewel.size == 2,
			})
		end
	end
	return sockets
end

function M:isSplitPersonality(item)
	if not item then return false end
	local n = (item.name or item.title or item.baseName or ""):lower()
	if n:find("split personality") then return true end
	if item.raw and tostring(item.raw):lower():find("split personality") then return true end
	return false
end

function M:collectSplitJewels(build)
	local jewels = {}
	local itemsTab = build.itemsTab
	if not itemsTab or not itemsTab.items then return jewels end
	for slot, item in pairs(itemsTab.items) do
		if item and self:isSplitPersonality(item) then
			table.insert(jewels, { slot = slot, item = item, itemId = item.id })
		end
	end
	-- Also scan Spec sockets when items are referenced by itemId
	local spec = build.spec
	if spec and spec.sockets then
		for nodeId, sock in pairs(spec.sockets) do
			local item = itemsTab.items and itemsTab.items[sock]
			if not item and itemsTab.items then
				for _, it in pairs(itemsTab.items) do
					if it and it.id == sock and self:isSplitPersonality(it) then
						table.insert(jewels, { slot = "Jewel " .. tostring(nodeId), item = it, nodeId = nodeId })
					end
				end
			end
		end
	end
	return jewels
end

function M:findSlotForNode(itemsTab, nodeId)
	local needle = tostring(nodeId)
	for slot, _ in pairs(itemsTab.items or {}) do
		if type(slot) == "string" and slot:find("Jewel") and slot:find(needle) then
			return slot
		end
	end
	-- PoB sometimes uses numeric socket maps
	if itemsTab.sockets and itemsTab.sockets[nodeId] then
		return "Jewel " .. needle
	end
	return nil
end

function M:optimize(build, archetype, options)
	options = options or {}
	local spec = build.spec
	local itemsTab = build.itemsTab
	if not spec or not itemsTab then return nil end
	if archetype and archetype.optimizeSplitPersonality == false then return nil end

	local startId = self:getStartNodeId(spec)
	if not startId then return nil end

	local allocNodes = {}
	for nodeId in pairs(spec.allocNodes or {}) do
		allocNodes[nodeId] = true
	end
	if not next(allocNodes) then
		for nodeId in pairs(spec.nodes or {}) do
			allocNodes[nodeId] = true
		end
	end

	local splitJewels = self:collectSplitJewels(build)
	if #splitJewels == 0 then return { moved = 0, sockets = {} } end

	local preferZigzag = true
	if options.preferZigzagPaths ~= nil then
		preferZigzag = options.preferZigzagPaths
	elseif archetype and archetype.preferZigzagPaths ~= nil then
		preferZigzag = archetype.preferZigzagPaths
	end

	local sockets = self:findJewelSockets(spec, allocNodes)
	if #sockets == 0 then return { moved = 0, sockets = {} } end

	for _, s in ipairs(sockets) do
		local sc = self:scoreSocket(spec, startId, s.id, allocNodes, preferZigzag)
		s.distStraight = sc.straight
		s.distAllocated = sc.allocated
		s.distZigzag = sc.zigzag
		s.dist = sc.best
	end
	table.sort(sockets, function(a, b) return a.dist > b.dist end)

	local moved = 0
	local assignments = {}
	for i, jewel in ipairs(splitJewels) do
		local target = sockets[i]
		if target then
			local farSlot = self:findSlotForNode(itemsTab, target.id)
			local curSlot = jewel.slot
			if farSlot and curSlot and farSlot ~= curSlot and itemsTab.SwapItems then
				local ok = pcall(function() itemsTab:SwapItems(curSlot, farSlot) end)
				if ok then
					moved = moved + 1
					jewel.slot = farSlot
				end
			end
			table.insert(assignments, {
				jewelSlot = jewel.slot,
				nodeId = target.id,
				allocatedPath = target.distAllocated,
				straight = target.distStraight,
				zigzag = target.distZigzag,
			})
		end
	end

	if options.mutateJewelPaths then
		self:mutatePathToSocket(build, spec, startId, sockets[1], allocNodes, preferZigzag)
	end

	build:BuildAll()
	return { moved = moved, sockets = assignments, preferZigzag = preferZigzag }
end

-- Extend / zigzag the allocated corridor toward the farthest socket
function M:mutatePathToSocket(build, spec, startId, farSocket, allocNodes, preferZigzag)
	if not farSocket then return end
	local targetId = farSocket.id
	local node = spec.tree.nodes[targetId]
	if not node or not node.linked then return end

	-- Add one unallocated neighbor near the far socket that lengthens the path
	local before = self:allocatedPathLength(spec, startId, targetId, allocNodes)
	for _, linkId in ipairs(node.linked) do
		if not allocNodes[linkId] then
			local ln = spec.tree.nodes[linkId]
			if ln and ln.alloc then
				local ok = pcall(function() spec:SelectNode(linkId) end)
				if ok then
					allocNodes[linkId] = true
					local after = self:allocatedPathLength(spec, startId, targetId, allocNodes)
					-- Keep only if zigzag preference and path got longer, or always if path equal+connected
					if preferZigzag and after < before then
						pcall(function()
							if spec.UnallocateNode then spec:UnallocateNode(linkId) end
						end)
						allocNodes[linkId] = nil
					else
						break
					end
				end
			end
		end
	end
end

return M
