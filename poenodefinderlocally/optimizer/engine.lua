-- engine.lua — Deep optimizer core (60/60 GA + tournament selection + cluster SP)
local json = require("dkjson")
local tournament = dofile(MainScriptPath .. "DeepOptimizer/tournament.lua")
local clusterOpt = dofile(MainScriptPath .. "DeepOptimizer/cluster_optimizer.lua")
local itemPool = dofile(MainScriptPath .. "DeepOptimizer/item_pool.lua")
local fitness = dofile(MainScriptPath .. "DeepOptimizer/fitness.lua")

local Engine = {}
Engine.__index = Engine
Engine.defaults = {}

function Engine:loadDefaults(path)
	local f = io.open(path, "r")
	if f then
		local raw = f:read("*a")
		f:close()
		local ok, data = pcall(json.decode, raw)
		if ok and data then
			self.defaults = data
		end
	end
end

function Engine:loadArchetype(name)
	local path = MainScriptPath .. "DeepOptimizer/configs/archetypes/" .. name .. ".json"
	local f = io.open(path, "r")
	if not f then
		return self.defaults.archetypes and self.defaults.archetypes.generic or {}
	end
	local raw = f:read("*a")
	f:close()
	local ok, data = pcall(json.decode, raw)
	return (ok and data) or {}
end

function Engine:snapshotTree(build)
	local spec = build.spec
	local nodes = {}
	for nodeId in pairs(spec.allocNodes or spec.nodes or {}) do
		nodes[nodeId] = true
	end
	return nodes
end

function Engine:applyTree(build, nodes)
	local spec = build.spec
	spec:ResetNodes()
	for nodeId in pairs(nodes) do
		spec:SelectNode(nodeId)
	end
end

function Engine:evaluate(build, nodes, archetype, options)
	self:applyTree(build, nodes)
	if options.optimizeClusters then
		clusterOpt:optimize(build, archetype, options)
	end
	if options.useTradeItems then
		itemPool:apply(build, archetype.itemPool or "trade_329")
	end
	build:BuildAll()
	return fitness:score(build, archetype, options)
end

function Engine:randomIndividual(spec, archetype, rng)
	local nodes = {}
	local seedNodes = archetype.mandatoryNodes or {}
	for _, id in ipairs(seedNodes) do
		nodes[id] = true
	end
	local candidates = {}
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.alloc and not nodes[nodeId] then
			table.insert(candidates, nodeId)
		end
	end
	local budget = (archetype.skillPoints or 120) - self:countNodes(nodes)
	for _ = 1, math.max(0, budget) do
		if #candidates == 0 then break end
		local idx = rng:random(1, #candidates)
		local pick = table.remove(candidates, idx)
		nodes[pick] = true
	end
	return nodes
end

function Engine:countNodes(nodes)
	local n = 0
	for _ in pairs(nodes) do n = n + 1 end
	return n
end

function Engine:mutate(nodes, spec, archetype, rng)
	local copy = {}
	for k, v in pairs(nodes) do copy[k] = v end
	if rng:random() < 0.5 then
		-- add random reachable node
		for nodeId, node in pairs(spec.tree.nodes) do
			if node.alloc and not copy[nodeId] and rng:random() < 0.02 then
				copy[nodeId] = true
				break
			end
		end
	else
		-- remove non-mandatory
		local mandatory = {}
		for _, id in ipairs(archetype.mandatoryNodes or {}) do mandatory[id] = true end
		local removable = {}
		for id in pairs(copy) do
			if not mandatory[id] then table.insert(removable, id) end
		end
		if #removable > 0 then
			copy[removable[rng:random(1, #removable)]] = nil
		end
	end
	return copy
end

function Engine:crossover(a, b, rng)
	local child = {}
	for id in pairs(a) do
		if b[id] or rng:random() < 0.5 then child[id] = true end
	end
	for id in pairs(b) do
		if a[id] or rng:random() < 0.5 then child[id] = true end
	end
	return child
end

function Engine:optimize(build, options)
	options = options or {}
	local archetypeName = options.archetype or "rf_arcane_devotion"
	local archetype = self:loadArchetype(archetypeName)
	local generations = options.generations or self.defaults.generations or 60
	local populationSize = options.population or self.defaults.population or 60
	local tournamentSize = self.defaults.tournamentSize or 5
	local mutationRate = self.defaults.mutationRate or 0.15
	local eliteCount = self.defaults.eliteCount or 4

	local rng = math.random
	math.randomseed(os.time())

	local spec = build.spec
	local population = {}
	for i = 1, populationSize do
		local ind = self:randomIndividual(spec, archetype, { random = function(_, a, b) return rng(a, b) end })
		local score = self:evaluate(build, ind, archetype, options)
		table.insert(population, { nodes = ind, fitness = score.total, detail = score })
	end

	local best = population[1]
	for g = 1, generations do
		table.sort(population, function(x, y) return x.fitness > y.fitness end)
		if population[1].fitness > best.fitness then
			best = population[1]
		end
		if options.onProgress then
			options.onProgress(g, best.fitness)
		end
		if options.requireRegen and best.detail and best.detail.netRegen and best.detail.netRegen <= 0 then
			-- penalize until regen positive; continue searching
		end

		local nextGen = {}
		for e = 1, math.min(eliteCount, #population) do
			table.insert(nextGen, population[e])
		end
		while #nextGen < populationSize do
			local p1 = tournament.select(population, tournamentSize, rng)
			local p2 = tournament.select(population, tournamentSize, rng)
			local childNodes = self:crossover(p1.nodes, p2.nodes, { random = rng })
			if rng() < mutationRate then
				childNodes = self:mutate(childNodes, spec, archetype, { random = rng })
			end
			local score = self:evaluate(build, childNodes, archetype, options)
			table.insert(nextGen, { nodes = childNodes, fitness = score.total, detail = score })
		end
		population = nextGen
	end

	table.sort(population, function(x, y) return x.fitness > y.fitness end)
	best = population[1]
	self:applyTree(build, best.nodes)
	if options.optimizeClusters then
		clusterOpt:optimize(build, archetype, options)
	end
	if options.useTradeItems then
		itemPool:apply(build, archetype.itemPool or "trade_329")
	end
	build:BuildAll()
	build:SyncTree()

	return {
		fitness = best.fitness,
		dps = best.detail and best.detail.dps,
		netRegen = best.detail and best.detail.netRegen,
		ehp = best.detail and best.detail.ehp,
		generations = generations,
		population = populationSize,
		nodes = best.nodes,
	}
end

return Engine
