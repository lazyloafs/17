-- tree_mutation.lua — Complete tree mutation with connectivity, budget, SP zigzag
-- Split Personality scales with allocated passives between socket and class start.
-- Zigzag (longer allocated path) increases SP effect; prefer distant sockets.

local M = {}

function M:copyNodes(nodes)
	local c = {}
	for k, v in pairs(nodes) do c[k] = v end
	return c
end

function M:countNodes(nodes)
	local n = 0
	for _ in pairs(nodes) do n = n + 1 end
	return n
end

function M:mandatorySet(archetype)
	local m = {}
	for _, id in ipairs(archetype.mandatoryNodes or {}) do m[id] = true end
	for _, id in ipairs(archetype.lockedNodes or {}) do m[id] = true end
	return m
end

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

-- BFS over allocated nodes only (returns distance / predecessor map)
function M:bfsAllocated(spec, startId, allocNodes)
	local dist = { [startId] = 0 }
	local prev = {}
	local queue = { startId }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		local node = spec.tree.nodes[cur]
		if node and node.linked then
			for _, linkId in ipairs(node.linked) do
				if not dist[linkId] and (allocNodes[linkId] or linkId == startId) then
					dist[linkId] = dist[cur] + 1
					prev[linkId] = cur
					table.insert(queue, linkId)
				end
			end
		end
	end
	return dist, prev
end

-- Count allocated passives on shortest allocated path start→target (SP mechanic)
function M:allocatedPathLength(spec, startId, targetId, allocNodes)
	if not startId or not targetId then return 0 end
	local dist = self:bfsAllocated(spec, startId, allocNodes)
	return dist[targetId] or 0
end

-- Keep only nodes reachable from start through allocated links; re-add mandatory
function M:repairConnectivity(nodes, spec, archetype)
	local startId = self:getStartNodeId(spec)
	if not startId then return nodes end
	nodes[startId] = true
	local dist = self:bfsAllocated(spec, startId, nodes)
	local repaired = { [startId] = true }
	for id in pairs(nodes) do
		if dist[id] then repaired[id] = true end
	end
	for id in pairs(self:mandatorySet(archetype)) do
		repaired[id] = true
	end
	-- If mandatory became disconnected, try to bridge via any link from connected set
	for mid in pairs(self:mandatorySet(archetype)) do
		if not dist[mid] then
			local mnode = spec.tree.nodes[mid]
			if mnode and mnode.linked then
				for _, linkId in ipairs(mnode.linked) do
					if repaired[linkId] then
						repaired[mid] = true
						break
					end
				end
			end
		end
	end
	return repaired
end

-- Enforce skill-point budget by removing lowest-value non-mandatory leaves first
function M:enforceBudget(nodes, spec, archetype, rng)
	local budget = archetype.skillPoints or 121
	local mandatory = self:mandatorySet(archetype)
	local startId = self:getStartNodeId(spec)
	local count = self:countNodes(nodes)
	while count > budget do
		local removable = {}
		for id in pairs(nodes) do
			if not mandatory[id] and id ~= startId then
				table.insert(removable, id)
			end
		end
		if #removable == 0 then break end
		-- Prefer removing nodes that are not jewel sockets and not on long SP paths
		local pick = removable[rng(1, #removable)]
		nodes[pick] = nil
		nodes = self:repairConnectivity(nodes, spec, archetype)
		count = self:countNodes(nodes)
		if count > budget and #removable == 1 then break end
	end
	-- Fill under-budget with neighbors of current tree (keeps connectivity)
	while count < budget do
		local candidates = {}
		for id in pairs(nodes) do
			local node = spec.tree.nodes[id]
			if node and node.linked then
				for _, linkId in ipairs(node.linked) do
					local ln = spec.tree.nodes[linkId]
					if ln and ln.alloc and not nodes[linkId] then
						table.insert(candidates, linkId)
					end
				end
			end
		end
		if #candidates == 0 then break end
		nodes[candidates[rng(1, #candidates)]] = true
		count = count + 1
	end
	return nodes
end

function M:randomAdd(nodes, spec, rng)
	local candidates = {}
	for id in pairs(nodes) do
		local node = spec.tree.nodes[id]
		if node and node.linked then
			for _, linkId in ipairs(node.linked) do
				local ln = spec.tree.nodes[linkId]
				if ln and ln.alloc and not nodes[linkId] then
					table.insert(candidates, linkId)
				end
			end
		end
	end
	if #candidates > 0 then
		nodes[candidates[rng(1, #candidates)]] = true
	end
	return nodes
end

function M:randomRemove(nodes, mandatory, startId, rng)
	local removable = {}
	for id in pairs(nodes) do
		if not mandatory[id] and id ~= startId then
			table.insert(removable, id)
		end
	end
	if #removable > 0 then
		nodes[removable[rng(1, #removable)]] = nil
	end
	return nodes
end

function M:pathReroute(nodes, spec, rng)
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.expansionJewel and nodes[nodeId] and rng() < 0.15 then
			nodes[nodeId] = nil
			return nodes
		elseif node.expansionJewel and not nodes[nodeId] and rng() < 0.08 then
			-- Only add if adjacent to allocated tree
			if node.linked then
				for _, linkId in ipairs(node.linked) do
					if nodes[linkId] then
						nodes[nodeId] = true
						return nodes
					end
				end
			end
		end
	end
	return nodes
end

-- Lengthen path toward farthest jewel socket (increases Split Personality scaling)
function M:zigzagExtend(nodes, spec, startId, rng)
	if not startId then return nodes end
	local sockets = {}
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.type == "Socket" and nodes[nodeId] then
			local pathLen = self:allocatedPathLength(spec, startId, nodeId, nodes)
			table.insert(sockets, { id = nodeId, pathLen = pathLen })
		end
	end
	if #sockets == 0 then return nodes end
	table.sort(sockets, function(a, b) return a.pathLen > b.pathLen end)

	-- Work on the farthest socket: add a detour neighbor then reconnect
	local target = sockets[1]
	local farNode = spec.tree.nodes[target.id]
	if not farNode or not farNode.linked then return nodes end

	-- Collect unallocated neighbors of the path corridor near the far socket
	local candidates = {}
	local dist = self:bfsAllocated(spec, startId, nodes)
	for nodeId in pairs(nodes) do
		local d = dist[nodeId]
		if d and d >= math.max(1, (target.pathLen or 1) - 4) then
			local node = spec.tree.nodes[nodeId]
			if node and node.linked then
				for _, linkId in ipairs(node.linked) do
					local ln = spec.tree.nodes[linkId]
					if ln and ln.alloc and not nodes[linkId] then
						-- Prefer nodes that connect back (create zigzag detour)
						local reconnects = false
						if ln.linked then
							for _, backId in ipairs(ln.linked) do
								if nodes[backId] and backId ~= nodeId then
									reconnects = true
									break
								end
							end
						end
						table.insert(candidates, { id = linkId, zigzag = reconnects })
					end
				end
			end
		end
	end
	if #candidates == 0 then
		-- Fallback: extend from far socket links
		for _, linkId in ipairs(farNode.linked) do
			local ln = spec.tree.nodes[linkId]
			if ln and ln.alloc and not nodes[linkId] then
				nodes[linkId] = true
				return nodes
			end
		end
		return nodes
	end
	-- Prefer zigzag candidates
	local zig = {}
	for _, c in ipairs(candidates) do
		if c.zigzag then table.insert(zig, c) end
	end
	local pool = (#zig > 0 and rng() < 0.7) and zig or candidates
	nodes[pool[rng(1, #pool)].id] = true
	return nodes
end

-- Move allocation toward a more distant jewel socket from start
function M:repositionTowardDistantSocket(nodes, spec, startId, rng)
	if not startId then return nodes end
	local allSockets = {}
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.type == "Socket" then
			local reachable = nodes[nodeId]
			local pathLen = reachable and self:allocatedPathLength(spec, startId, nodeId, nodes) or 0
			-- Approximate straight graph distance for unallocated sockets
			local straight = 0
			if not reachable then
				local visited = { [startId] = 0 }
				local q = { startId }
				local h = 1
				while h <= #q do
					local cur = q[h]; h = h + 1
					local n = spec.tree.nodes[cur]
					if n and n.linked then
						for _, lid in ipairs(n.linked) do
							if not visited[lid] then
								visited[lid] = visited[cur] + 1
								if lid == nodeId then straight = visited[lid]; break end
								table.insert(q, lid)
							end
						end
					end
					if straight > 0 then break end
				end
			end
			table.insert(allSockets, {
				id = nodeId,
				alloc = reachable,
				score = reachable and pathLen or (straight * 0.5),
			})
		end
	end
	table.sort(allSockets, function(a, b) return a.score > b.score end)
	-- Ensure a high-scoring socket is allocated by walking from nearest allocated neighbor
	for i = 1, math.min(3, #allSockets) do
		local s = allSockets[i]
		if not s.alloc then
			local node = spec.tree.nodes[s.id]
			if node and node.linked then
				for _, linkId in ipairs(node.linked) do
					if nodes[linkId] then
						nodes[s.id] = true
						return nodes
					end
				end
			end
		end
	end
	return nodes
end

function M:mutate(nodes, spec, archetype, rng, rate)
	rate = rate or 0.2
	local copy = self:copyNodes(nodes)
	local mandatory = self:mandatorySet(archetype)
	local startId = self:getStartNodeId(spec)
	local roll = rng()

	if roll < rate * 0.25 then
		copy = self:randomAdd(copy, spec, rng)
	elseif roll < rate * 0.40 then
		copy = self:randomRemove(copy, mandatory, startId, rng)
	elseif roll < rate * 0.55 then
		copy = self:pathReroute(copy, spec, rng)
	elseif roll < rate * 0.75 then
		copy = self:zigzagExtend(copy, spec, startId, rng)
	elseif roll < rate * 0.90 then
		copy = self:repositionTowardDistantSocket(copy, spec, startId, rng)
	else
		copy = self:randomAdd(copy, spec, rng)
		copy = self:zigzagExtend(copy, spec, startId, rng)
	end

	copy = self:repairConnectivity(copy, spec, archetype)
	copy = self:enforceBudget(copy, spec, archetype, rng)
	return copy
end

function M:mutateFromBest(bestNodes, spec, archetype, count, rng)
	local variants = {}
	for i = 1, count do
		local v = self:copyNodes(bestNodes)
		v = self:mutate(v, spec, archetype, rng, 0.25 + rng() * 0.20)
		table.insert(variants, v)
	end
	return variants
end

return M
