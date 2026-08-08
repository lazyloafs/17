-- engine.lua — Dual-phase 60+60 GA: main objective then opposite while retaining phase-1 progress

local json = require("dkjson")
local tournament = dofile(MainScriptPath .. "DeepOptimizer/tournament.lua")
local clusterOpt = dofile(MainScriptPath .. "DeepOptimizer/cluster_optimizer.lua")
local itemPool = dofile(MainScriptPath .. "DeepOptimizer/item_pool.lua")
local fitness = dofile(MainScriptPath .. "DeepOptimizer/fitness.lua")
local treeMut = dofile(MainScriptPath .. "DeepOptimizer/tree_mutation.lua")
local jewelOpt = dofile(MainScriptPath .. "DeepOptimizer/jewel_optimizer.lua")

local Engine = {}
Engine.__index = Engine
Engine.defaults = {}

function Engine:loadDefaults(path)
	local f = io.open(path, "r")
	if f then
		local raw = f:read("*a")
		f:close()
		local ok, data = pcall(json.decode, raw)
		if ok and data then self.defaults = data end
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
		itemPool:apply(build, archetype.itemPool or "trade_329_rf")
	end
	if options.optimizeJewels ~= false then
		jewelOpt:optimize(build, archetype, options)
	end
	build:BuildAll()
	return fitness:score(build, archetype, options)
end

function Engine:randomIndividual(spec, archetype, rng, seedNodes)
	local nodes = {}
	for _, id in ipairs(seedNodes or archetype.mandatoryNodes or {}) do
		nodes[id] = true
	end
	local candidates = {}
	for nodeId, node in pairs(spec.tree.nodes) do
		if node.alloc and not nodes[nodeId] then
			table.insert(candidates, nodeId)
		end
	end
	local budget = (archetype.skillPoints or 121) - self:countNodes(nodes)
	for _ = 1, math.max(0, budget) do
		if #candidates == 0 then break end
		local pick = table.remove(candidates, rng(1, #candidates))
		nodes[pick] = true
	end
	return nodes
end

function Engine:countNodes(nodes)
	local n = 0
	for _ in pairs(nodes) do n = n + 1 end
	return n
end

function Engine:crossover(a, b, rng)
	local child = {}
	for id in pairs(a) do
		if b[id] or rng() < 0.5 then child[id] = true end
	end
	for id in pairs(b) do
		if a[id] or rng() < 0.5 then child[id] = true end
	end
	return child
end

function Engine:runPhase(build, spec, archetype, options, phase, seedPopulation)
	local generations = options.generations or 60
	local populationSize = options.population or 60
	local tournamentSize = self.defaults.tournamentSize or 5
	local mutationRate = self.defaults.mutationRate or 0.15
	local eliteCount = self.defaults.eliteCount or 6
	local rng = math.random

	local phaseOptions = {}
	for k, v in pairs(options) do phaseOptions[k] = v end
	phaseOptions.phase = phase

	local population = seedPopulation or {}
	if #population == 0 then
		for i = 1, populationSize do
			local ind = self:randomIndividual(spec, archetype, rng)
			local score = self:evaluate(build, ind, archetype, phaseOptions)
			table.insert(population, { nodes = ind, fitness = score.total, detail = score })
		end
	else
		while #population < populationSize do
			local idx = rng(1, math.min(#seedPopulation, eliteCount))
			local mut = treeMut:mutate(seedPopulation[idx].nodes, spec, archetype, rng, mutationRate)
			local score = self:evaluate(build, mut, archetype, phaseOptions)
			table.insert(population, { nodes = mut, fitness = score.total, detail = score })
		end
	end

	local best = population[1]
	local phaseLabel = phase == "main" and "DPS" or "Regen/EHP"

	for g = 1, generations do
		table.sort(population, function(x, y) return x.fitness > y.fitness end)
		if population[1].fitness > (best.fitness or 0) then best = population[1] end
		if options.onProgress then
			options.onProgress(g, best.fitness, phaseLabel)
		end

		local nextGen = {}
		for e = 1, math.min(eliteCount, #population) do
			table.insert(nextGen, population[e])
		end
		while #nextGen < populationSize do
			local p1 = tournament.select(population, tournamentSize, rng)
			local p2 = tournament.select(population, tournamentSize, rng)
			local childNodes = self:crossover(p1.nodes, p2.nodes, rng)
			if rng() < mutationRate then
				childNodes = treeMut:mutate(childNodes, spec, archetype, rng, mutationRate)
			end
			local score = self:evaluate(build, childNodes, archetype, phaseOptions)
			table.insert(nextGen, { nodes = childNodes, fitness = score.total, detail = score })
		end
		population = nextGen
	end

	table.sort(population, function(x, y) return x.fitness > y.fitness end)
	return population[1], population
end

function Engine:optimize(build, options)
	options = options or {}
	local archetypeName = options.archetype or "rf_arcane_devotion"
	local archetype = self:loadArchetype(archetypeName)
	local generations = options.generations or self.defaults.generations or 60
	local populationSize = options.population or self.defaults.population or 60
	local dualPhase = options.dualPhase ~= false

	options.generations = generations
	options.population = populationSize
	options.mutateJewelPaths = true

	math.randomseed(os.time())
	local spec = build.spec

	-- Phase 1: main objective (max DPS / mana scaling)
	local phase1Best, phase1Pop = self:runPhase(build, spec, archetype, options, "main", nil)
	local phase1Floor = {
		dps = phase1Best.detail.dps,
		netRegen = phase1Best.detail.netRegen,
		ehp = phase1Best.detail.ehp,
		nodes = phase1Best.nodes,
	}

	local finalBest = phase1Best
	local phase2Best = nil

	if dualPhase then
		-- Phase 2: opposite objective (regen/eHP) seeded from phase-1 elites — retains DPS floor
		local phase2Options = {}
		for k, v in pairs(options) do phase2Options[k] = v end
		phase2Options.phase1Floor = phase1Floor

		phase2Best, _ = self:runPhase(build, spec, archetype, phase2Options, "opposite", phase1Pop)
		if phase2Best.detail.dps >= phase1Floor.dps * (archetype.dpsRetainRatio or 0.92) then
			finalBest = phase2Best
		else
			-- Keep phase-1 tree if phase-2 lost too much DPS
			finalBest = phase1Best
		end
	end

	-- Final jewel reposition pass (split personality distance / zigzag)
	self:applyTree(build, finalBest.nodes)
	jewelOpt:optimize(build, archetype, { mutateJewelPaths = true, optimizeJewels = true })
	if options.optimizeClusters then clusterOpt:optimize(build, archetype, options) end
	if options.useTradeItems then itemPool:apply(build, archetype.itemPool or "trade_329_rf") end
	build:BuildAll()
	build:SyncTree()

	return {
		fitness = finalBest.fitness,
		dps = finalBest.detail.dps,
		netRegen = finalBest.detail.netRegen,
		ehp = finalBest.detail.ehp,
		phase1 = {
			dps = phase1Floor.dps,
			netRegen = phase1Floor.netRegen,
			ehp = phase1Floor.ehp,
		},
		phase2 = phase2Best and {
			dps = phase2Best.detail.dps,
			netRegen = phase2Best.detail.netRegen,
			ehp = phase2Best.detail.ehp,
		} or nil,
		generations = generations,
		population = populationSize,
		dualPhase = dualPhase,
		nodes = finalBest.nodes,
	}
end

return Engine
