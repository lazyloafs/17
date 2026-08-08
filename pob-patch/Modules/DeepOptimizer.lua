-- DeepOptimizer.lua — PoB UI integration for localoptimizer
-- Tree tab buttons: Opt DPS / Opt Tank (one-click deep optimize)

local DeepOptimizer = {}
DeepOptimizer.__index = DeepOptimizer

function DeepOptimizer:Init(buildModule)
	self.buildModule = buildModule
	self.engine = dofile(MainScriptPath .. "DeepOptimizer/engine.lua")
	self.headless = dofile(MainScriptPath .. "DeepOptimizer/headless.lua")
	self.engine:loadDefaults(MainScriptPath .. "DeepOptimizer/configs/optimizer-defaults.json")
	self.running = false
end

function DeepOptimizer:GetActiveBuild()
	local main = self.buildModule
	if main and main.mode == "BUILD" and main.modes and main.modes.BUILD then
		return main.modes.BUILD
	end
	return nil
end

function DeepOptimizer:Run(options)
	local build = self:GetActiveBuild()
	if not build then
		return nil, "Open a build first."
	end
	options = options or {}
	return self.engine:optimize(build, options)
end

function DeepOptimizer:RunHeadless(build, options)
	return self.engine:optimize(build, options or { headless = true })
end

function DeepOptimizer:DefaultOptions(mode)
	local defaults = self.engine.defaults or {}
	return {
		generations = defaults.generations or 60,
		population = defaults.population or 60,
		useTradeItems = true,
		optimizeClusters = true,
		requireRegen = mode == "tank",
		optimizeJewels = true,
		mutateJewelPaths = true,
		dualPhase = false,
		singlePhase = mode == "tank" and "opposite" or "main",
		archetype = mode == "tank" and "generic_tanky" or "generic_dps",
	}
end

function DeepOptimizer:SetButtonStatus(treeTab, mode, text)
	local btn = mode == "tank" and treeTab.controls.optTankButton or treeTab.controls.optDpsButton
	if btn then
		btn.label = text
	end
end

function DeepOptimizer:RunQuickOptimize(treeTab, mode)
	if self.running then
		return
	end
	local build = treeTab.build
	if not build then
		return
	end

	self.running = true
	local label = mode == "tank" and "Opt Tank" or "Opt DPS"
	local options = self:DefaultOptions(mode)
	local gens = options.generations

	self:SetButtonStatus(treeTab, mode, "Running...")
	ConPrintf("localoptimizer: %s started (%d gens)\n", label, gens)

	local result, err = self:Run({
		archetype = options.archetype,
		generations = gens,
		population = options.population,
		useTradeItems = options.useTradeItems,
		optimizeClusters = options.optimizeClusters,
		requireRegen = options.requireRegen,
		dualPhase = false,
		singlePhase = options.singlePhase,
		optimizeJewels = options.optimizeJewels,
		mutateJewelPaths = options.mutateJewelPaths,
		onProgress = function(gen, best, phaseLabel)
			if gen % 10 == 0 or gen == gens then
				ConPrintf("localoptimizer: %s gen %d/%d — fitness %.2f\n", phaseLabel or label, gen, gens, best)
			end
		end,
	})

	self.running = false
	self:SetButtonStatus(treeTab, mode, label)

	if not result then
		ConPrintf("localoptimizer: %s failed — %s\n", label, tostring(err))
		return
	end

	ConPrintf("localoptimizer: %s done — DPS %.0f, regen +%.0f/s, eHP %.0f\n",
		label, result.dps or 0, result.netRegen or 0, result.ehp or 0)
	build:SyncTree()
	build:BuildAll()
end

function DeepOptimizer:AddTreeTabButtons(treeTab)
	if treeTab.controls and treeTab.controls.optDpsButton then
		return
	end
	treeTab.controls = treeTab.controls or {}

	local anchor = treeTab.controls.powerReport or treeTab.controls.findTimelessJewel or treeTab.controls.treeSearch

	treeTab.controls.optDpsButton = new("ButtonControl",
		{ "LEFT", anchor, "RIGHT" }, { 8, 0, 72, 20 }, "Opt DPS", function()
			self:RunQuickOptimize(treeTab, "dps")
		end)

	treeTab.controls.optTankButton = new("ButtonControl",
		{ "LEFT", treeTab.controls.optDpsButton, "RIGHT" }, { 4, 0, 72, 20 }, "Opt Tank", function()
			self:RunQuickOptimize(treeTab, "tank")
		end)
end

function DeepOptimizer:HookBuild(build, treeTab)
	treeTab = treeTab or (build and build.treeTab)
	if not treeTab or treeTab._deepOptimizerHooked then
		return
	end
	treeTab._deepOptimizerHooked = true
	self:AddTreeTabButtons(treeTab)
	if build then
		self.headless:tryRun(build, self)
	end
end

return DeepOptimizer
