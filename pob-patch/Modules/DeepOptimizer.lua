-- DeepOptimizer.lua — PoB UI integration for localoptimizer
-- Dual-phase 60+60 GA with Split Personality zigzag repositioning.

local DeepOptimizer = {}
DeepOptimizer.__index = DeepOptimizer

function DeepOptimizer:Init(buildModule)
	self.buildModule = buildModule
	self.engine = dofile(MainScriptPath .. "DeepOptimizer/engine.lua")
	self.headless = dofile(MainScriptPath .. "DeepOptimizer/headless.lua")
	self.engine:loadDefaults(MainScriptPath .. "DeepOptimizer/configs/optimizer-defaults.json")
	-- Process pending headless request if Launch_PoB_with_Optimizer.bat optimize was used
	local build = self:GetActiveBuild()
	if build then
		self.headless:tryRun(build, self)
	end
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

function DeepOptimizer:AddTreeTabButton(treeTab)
	if treeTab.controls and treeTab.controls.deepOptimizeButton then
		return
	end
	treeTab.controls = treeTab.controls or {}
	treeTab.controls.deepOptimizeButton = new("ButtonControl", {
		"TREE", "DeepOptimize",
	}, "12", "Deep Optimize", function()
		self:ShowOptimizeDialog(treeTab)
	end)
end

function DeepOptimizer:ShowOptimizeDialog(treeTab)
	local build = treeTab.build
	local defaults = self.engine.defaults or {}
	local controls = {}
	local status = "Ready — 60 main + 60 opposite gens."

	controls.statusLabel = new("LabelControl", { "TOPLEFT", controls, "TOPLEFT" }, { 0, 20, 420, 16 }, status)
	controls.archetypeList = new("DropDownControl", { "TOPLEFT", controls.statusLabel, "BOTTOMLEFT" }, { 0, 8, 220, 20 },
		{ "rf_arcane_devotion", "generic_dps", "generic_tanky" }, function(index, value)
			self.selectedArchetype = value
		end)
	controls.archetypeLabel = new("LabelControl", { "RIGHT", controls.archetypeList, "LEFT" }, { -8, 0, 0, 16 }, "Archetype:")
	controls.generationsEdit = new("EditControl", { "TOPLEFT", controls.archetypeList, "BOTTOMLEFT" }, { 0, 8, 60, 20 }, tostring(defaults.generations or 60))
	controls.generationsLabel = new("LabelControl", { "RIGHT", controls.generationsEdit, "LEFT" }, { -8, 0, 0, 16 }, "Gens/phase:")
	controls.populationEdit = new("EditControl", { "LEFT", controls.generationsEdit, "RIGHT" }, { 8, 0, 60, 20 }, tostring(defaults.population or 60))
	controls.populationLabel = new("LabelControl", { "RIGHT", controls.populationEdit, "LEFT" }, { -8, 0, 0, 16 }, "Population:")
	controls.tradeItemsCheck = new("CheckBoxControl", { "TOPLEFT", controls.generationsEdit, "BOTTOMLEFT" }, { 0, 8, 18 }, "Use trade item pool (non-self-owned)", function(state)
		self.useTradeItems = state
	end)
	controls.tradeItemsCheck.state = true
	controls.clusterCheck = new("CheckBoxControl", { "TOPLEFT", controls.tradeItemsCheck, "BOTTOMLEFT" }, { 0, 4, 18 }, "Optimize cluster SP routing", function(state)
		self.optimizeClusters = state
	end)
	controls.clusterCheck.state = true
	controls.regenCheck = new("CheckBoxControl", { "TOPLEFT", controls.clusterCheck, "BOTTOMLEFT" }, { 0, 4, 18 }, "Require net positive regen", function(state)
		self.requireRegen = state
	end)
	controls.regenCheck.state = true

	controls.dualPhaseCheck = new("CheckBoxControl", { "TOPLEFT", controls.regenCheck, "BOTTOMLEFT" }, { 0, 4, 18 }, "Dual phase: 60 main + 60 opposite (retain DPS)", function(state)
		self.dualPhase = state
	end)
	controls.dualPhaseCheck.state = true
	controls.jewelCheck = new("CheckBoxControl", { "TOPLEFT", controls.dualPhaseCheck, "BOTTOMLEFT" }, { 0, 4, 18 }, "Reposition Split Personality (distance/zigzag)", function(state)
		self.optimizeJewels = state
	end)
	controls.jewelCheck.state = true
	controls.zigzagCheck = new("CheckBoxControl", { "TOPLEFT", controls.jewelCheck, "BOTTOMLEFT" }, { 0, 4, 18 }, "Prefer zigzag (longer allocated path) for SP", function(state)
		self.preferZigzag = state
	end)
	controls.zigzagCheck.state = true

	controls.runButton = new("ButtonControl", { "TOPLEFT", controls.zigzagCheck, "BOTTOMLEFT" }, { 0, 12, 160, 20 }, "Run 60+60", function()
		local gens = tonumber(controls.generationsEdit.buf) or 60
		controls.statusLabel.label = "Phase 1/2 (main DPS)..."
		local result, err = self:Run({
			archetype = self.selectedArchetype or "rf_arcane_devotion",
			generations = gens,
			population = tonumber(controls.populationEdit.buf) or 60,
			useTradeItems = controls.tradeItemsCheck.state,
			optimizeClusters = controls.clusterCheck.state,
			requireRegen = controls.regenCheck.state,
			dualPhase = controls.dualPhaseCheck.state,
			optimizeJewels = controls.jewelCheck.state,
			mutateJewelPaths = controls.jewelCheck.state,
			preferZigzagPaths = controls.zigzagCheck.state,
			phase1EliteCarryover = (defaults.phase1EliteCarryover or 12),
			phase2MutationRate = (defaults.phase2MutationRate or 0.20),
			onProgress = function(gen, best, phaseLabel)
				controls.statusLabel.label = string.format("%s gen %d/%d — fitness %.2f", phaseLabel or "Main", gen, gens, best)
			end,
		})
		if not result then
			controls.statusLabel.label = "Error: " .. tostring(err)
			return
		end
		local msg = string.format("Done [%s] — DPS %.0f, regen +%.0f/s", result.selected or "?", result.dps or 0, result.netRegen or 0)
		if result.phase1 then
			msg = msg .. string.format(" | P1 DPS %.0f", result.phase1.dps or 0)
		end
		if result.phase2 then
			msg = msg .. string.format(" | P2 regen +%.0f", result.phase2.netRegen or 0)
		end
		if result.splitPersonality and result.splitPersonality.moved then
			msg = msg .. string.format(" | SP moved %d", result.splitPersonality.moved)
		end
		controls.statusLabel.label = msg
		if build.SyncTree then build:SyncTree() end
		build:BuildAll()
	end)

	self.selectedArchetype = "rf_arcane_devotion"
	self.useTradeItems = true
	self.optimizeClusters = true
	self.requireRegen = true
	self.dualPhase = true
	self.optimizeJewels = true
	self.preferZigzag = true
end

-- Hook into Build module after tree tab loads
function DeepOptimizer:HookBuild(build)
	if build.treeTab and not build.treeTab._deepOptimizerHooked then
		build.treeTab._deepOptimizerHooked = true
		self:AddTreeTabButton(build.treeTab)
	end
end

return DeepOptimizer
