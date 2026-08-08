-- tree_mutation.lua — Complete tree mutation: nodes, paths, clusters, jewel routes

local M = {}

function M:copyNodes(nodes)
	local c = {}
	for k, v in pairs(nodes) do c[k] = v end
	return c
end

function M:mandatorySet(archetype)
	local m = {}
	for _, id in ipairs(archetype.mandatoryNodes or {}) do m[id] = true end
	for _, id in ipairs(archetype.lockedNodes or {}) do m[id] = true end
	return m
end

function M:randomAdd(nodes, spec, rng)
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.alloc and not nodes[nodeId] and rng() < 0.03 then
			nodes[nodeId] = true
			return nodes
		end
	end
	return nodes
end

function M:randomRemove(nodes, mandatory, rng)
	local removable = {}
	for id in pairs(nodes) do
		if not mandatory[id] then table.insert(removable, id) end
	end
	if #removable > 0 then
		nodes[removable[rng(1, #removable)]] = nil
	end
	return nodes
end

function M:pathReroute(nodes, spec, rng)
	-- Toggle a cluster entry node if allocated
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.expansionJewel and nodes[nodeId] and rng() < 0.1 then
			nodes[nodeId] = nil
			return nodes
		elseif node.expansionJewel and not nodes[nodeId] and rng() < 0.05 then
			nodes[nodeId] = true
			return nodes
		end
	end
	return nodes
end

function M:zigzagExtend(nodes, spec, startId, rng)
	-- Extend path away from start for Split Personality distance (prefer non-shortest routes)
	local bestFar = nil
	local bestDist = 0
	for nodeId in pairs(nodes) do
		local node = spec.tree.nodes[nodeId]
		if node and node.type == "Socket" then
			local d = 0
			for nid in pairs(nodes) do d = d + 1 end
			if d > bestDist then bestDist = d; bestFar = nodeId end
		end
	end
	if not bestFar then return nodes end
	local farNode = spec.tree.nodes[bestFar]
	if farNode and farNode.linked then
		for _, linkId in ipairs(farNode.linked) do
			local ln = spec.tree.nodes[linkId]
			if ln and ln.alloc and not nodes[linkId] and rng() < 0.3 then
				nodes[linkId] = true
				break
			end
		end
	end
	return nodes
end

function M:mutate(nodes, spec, archetype, rng, rate)
	rate = rate or 0.2
	local copy = self:copyNodes(nodes)
	local mandatory = self:mandatorySet(archetype)
	local roll = rng()

	if roll < rate * 0.35 then
		copy = self:randomAdd(copy, spec, rng)
	elseif roll < rate * 0.55 then
		copy = self:randomRemove(copy, mandatory, rng)
	elseif roll < rate * 0.75 then
		copy = self:pathReroute(copy, spec, rng)
	elseif roll < rate * 0.9 then
		local startId = nil
		for nodeId, node in pairs(spec.tree.nodes) do
			if node.isStart then startId = nodeId; break end
		end
		copy = self:zigzagExtend(copy, spec, startId, rng)
	else
		copy = self:randomAdd(copy, spec, rng)
		copy = self:pathReroute(copy, spec, rng)
	end
	return copy
end

function M:mutateFromBest(bestNodes, spec, archetype, count, rng)
	local variants = {}
	for i = 1, count do
		local v = self:copyNodes(bestNodes)
		v = self:mutate(v, spec, archetype, rng, 0.25 + rng() * 0.15)
		table.insert(variants, v)
	end
	return variants
end

return M
