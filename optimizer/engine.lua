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
	local score = fitness:score(build, archetype, options)
	-- Annotate with SP path lengths for reporting / secondary fitness
	if options.optimizeJewels ~= false then
		local startId = treeMut:getStartNodeId(build.spec)
		local alloc = {}
		for id in pairs(nodes) do alloc[id] = true end
		local spBonus = 0
		for nodeId, node in pairs(build.spec.tree.nodes) do
			if node.type == "Socket" and alloc[nodeId] then
				local plen = treeMut:allocatedPathLength(build.spec, startId, nodeId, alloc)
				if plen > spBonus then spBonus = plen end
			end
		end
		score.splitPersonalityPath = spBonus
		score.total = score.total + spBonus * (options.spPathWeight or 50)
	end
	return score
end

function Engine:seedFromCurrent(build)
	local nodes = {}
	local spec = build.spec
	for nodeId in pairs(spec.allocNodes or {}) do
		nodes[nodeId] = true
	end
	return nodes
end

function Engine:randomIndividual(spec, archetype, rng, seedNodes)
	local nodes = {}
	for _, id in ipairs(seedNodes or archetype.mandatoryNodes or {}) do
		nodes[id] = true
	end
	local startId = treeMut:getStartNodeId(spec)
	if startId then nodes[startId] = true end

	-- Grow a connected tree from start / seed (not random disconnected picks)
	local budget = archetype.skillPoints or 121
	local guard = 0
	while treeMut:countNodes(nodes) < budget and guard < budget * 4 do
		guard = guard + 1
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
	end
	nodes = treeMut:repairConnectivity(nodes, spec, archetype)
	nodes = treeMut:enforceBudget(nodes, spec, archetype, rng)
	return nodes
end

function Engine:countNodes(nodes)
	return treeMut:countNodes(nodes)
end

function Engine:crossover(a, b, spec, archetype, rng)
	local child = {}
	for id in pairs(a) do
		if b[id] or rng() < 0.5 then child[id] = true end
	end
	for id in pairs(b) do
		if a[id] or rng() < 0.5 then child[id] = true end
	end
	child = treeMut:repairConnectivity(child, spec, archetype)
	child = treeMut:enforceBudget(child, spec, archetype, rng)
	return child
end

function Engine:runPhase(build, spec, archetype, options, phase, seedPopulation)
	local generations = options.generations or 60
	local populationSize = options.population or 60
	local tournamentSize = options.tournamentSize or self.defaults.tournamentSize or 5
	local mutationRate = options.mutationRate or self.defaults.mutationRate or 0.15
	if phase == "opposite" then
		mutationRate = options.phase2MutationRate or self.defaults.phase2MutationRate or (mutationRate + 0.05)
	end
	local eliteCount = options.eliteCount or self.defaults.eliteCount or 6
	local rng = math.random

	local phaseOptions = {}
	for k, v in pairs(options) do phaseOptions[k] = v end
	phaseOptions.phase = phase

	local population = {}
	if seedPopulation and #seedPopulation > 0 then
		-- Carry phase-1 elites forward (retain first objective progress)
		local carry = math.min(
			#seedPopulation,
			options.phase1EliteCarryover or self.defaults.phase1EliteCarryover or 12
		)
		for i = 1, carry do
			local ind = seedPopulation[i]
			local score = self:evaluate(build, ind.nodes, archetype, phaseOptions)
			table.insert(population, { nodes = ind.nodes, fitness = score.total, detail = score })
		end
		while #population < populationSize do
			local idx = rng(1, math.min(#seedPopulation, carry))
			local mut = treeMut:mutate(seedPopulation[idx].nodes, spec, archetype, rng, mutationRate)
			local score = self:evaluate(build, mut, archetype, phaseOptions)
			table.insert(population, { nodes = mut, fitness = score.total, detail = score })
		end
	else
		-- Seed one individual from the currently loaded build
		local current = self:seedFromCurrent(build)
		if next(current) then
			local score = self:evaluate(build, current, archetype, phaseOptions)
			table.insert(population, { nodes = current, fitness = score.total, detail = score })
		end
		while #population < populationSize do
			local ind = self:randomIndividual(spec, archetype, rng)
			local score = self:evaluate(build, ind, archetype, phaseOptions)
			table.insert(population, { nodes = ind, fitness = score.total, detail = score })
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
			local childNodes = self:crossover(p1.nodes, p2.nodes, spec, archetype, rng)
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

function Engine:writeReport(result, options)
	local settingsPath = os.getenv("APPDATA")
	if not settingsPath then return end
	local path = settingsPath .. "/Path of Building/Settings/localoptimizer_last_result.json"
	local payload = {
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		archetype = options.archetype,
		generations = result.generations,
		population = result.population,
		dualPhase = result.dualPhase,
		selected = result.selected,
		dps = result.dps,
		netRegen = result.netRegen,
		ehp = result.ehp,
		phase1 = result.phase1,
		phase2 = result.phase2,
		splitPersonality = result.splitPersonality,
	}
	local ok, encoded = pcall(json.encode, payload)
	if not ok then return end
	local f = io.open(path, "w")
	if f then
		f:write(encoded)
		f:close()
	end
end

function Engine:optimize(build, options)
	options = options or {}
	local archetypeName = options.archetype or "rf_arcane_devotion"
	local archetype = self:loadArchetype(archetypeName)
	local generations = options.generations or self.defaults.generations or 60
	local populationSize = options.population or self.defaults.population or 60
	local dualPhase = options.dualPhase
	if dualPhase == nil then dualPhase = self.defaults.dualPhase ~= false end

	options.archetype = archetypeName
	options.generations = generations
	options.population = populationSize
	options.mutateJewelPaths = options.mutateJewelPaths ~= false
	options.preferZigzagPaths = options.preferZigzagPaths
	if options.preferZigzagPaths == nil then
		options.preferZigzagPaths = archetype.preferZigzagPaths ~= false
	end
	options.optimizeJewels = options.optimizeJewels ~= false
	options.tournamentSize = options.tournamentSize or self.defaults.tournamentSize
	options.mutationRate = options.mutationRate or self.defaults.mutationRate
	options.eliteCount = options.eliteCount or self.defaults.eliteCount
	options.phase1EliteCarryover = options.phase1EliteCarryover or self.defaults.phase1EliteCarryover or 12
	options.phase2MutationRate = options.phase2MutationRate or self.defaults.phase2MutationRate or 0.20

	math.randomseed(os.time())
	local spec = build.spec

	-- Phase 1: main objective (max DPS / mana scaling) — 60 gens
	local phase1Best, phase1Pop = self:runPhase(build, spec, archetype, options, "main", nil)
	local phase1Floor = {
		dps = phase1Best.detail.dps,
		netRegen = phase1Best.detail.netRegen,
		ehp = phase1Best.detail.ehp,
		mana = phase1Best.detail.mana,
		nodes = phase1Best.nodes,
	}

	local finalBest = phase1Best
	local phase2Best = nil
	local selected = "phase1"

	if dualPhase then
		-- Phase 2: opposite objective (regen/eHP) seeded from phase-1 elites — retains DPS floor
		local phase2Options = {}
		for k, v in pairs(options) do phase2Options[k] = v end
		phase2Options.phase1Floor = phase1Floor

		phase2Best, _ = self:runPhase(build, spec, archetype, phase2Options, "opposite", phase1Pop)
		local retain = archetype.dpsRetainRatio or 0.92
		if phase2Best.detail.dps >= phase1Floor.dps * retain then
			finalBest = phase2Best
			selected = "phase2"
		else
			finalBest = phase1Best
			selected = "phase1"
		end
	end

	-- Final jewel reposition pass (split personality distance / zigzag)
	self:applyTree(build, finalBest.nodes)
	local spResult = jewelOpt:optimize(build, archetype, {
		mutateJewelPaths = true,
		optimizeJewels = true,
		preferZigzagPaths = options.preferZigzagPaths,
	})
	if options.optimizeClusters then clusterOpt:optimize(build, archetype, options) end
	if options.useTradeItems then itemPool:apply(build, archetype.itemPool or "trade_329_rf") end
	build:BuildAll()
	if build.SyncTree then build:SyncTree() end

	local result = {
		fitness = finalBest.fitness,
		dps = finalBest.detail.dps,
		netRegen = finalBest.detail.netRegen,
		ehp = finalBest.detail.ehp,
		mana = finalBest.detail.mana,
		selected = selected,
		phase1 = {
			dps = phase1Floor.dps,
			netRegen = phase1Floor.netRegen,
			ehp = phase1Floor.ehp,
			mana = phase1Floor.mana,
		},
		phase2 = phase2Best and {
			dps = phase2Best.detail.dps,
			netRegen = phase2Best.detail.netRegen,
			ehp = phase2Best.detail.ehp,
			mana = phase2Best.detail.mana,
		} or nil,
		splitPersonality = spResult,
		generations = generations,
		population = populationSize,
		dualPhase = dualPhase,
		nodes = finalBest.nodes,
	}
	self:writeReport(result, options)
	return result
end

return Engine
