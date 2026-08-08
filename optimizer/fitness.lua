-- fitness.lua — Dual-phase scoring: main (DPS) then opposite (regen/eHP) retaining phase-1 floor

local M = {}

function M.getWeights(archetype, phase)
	phase = phase or "main"
	if phase == "opposite" then
		return archetype.oppositeWeights or {
			dps = 0.15,
			regen = 1.0,
			ehp = 0.0004,
			mana = 0.001,
			fireRes = 0.6,
		}
	end
	return archetype.weights or archetype.mainWeights or {
		dps = 1.0,
		regen = 0.2,
		ehp = 0.00005,
		mana = 0.003,
		fireRes = 0.5,
	}
end

function M.rawStats(build)
	local output = build.calcsTab.mainOutput
	local dps = output.TotalDPS or output.CombinedDPS or 0
	local lifeRegen = output.LifeRegenRecovery or 0
	local esRegen = output.ESRegenRecovery or 0
	local netRegen = lifeRegen + esRegen
	if output.RFCostLife then
		netRegen = netRegen - output.RFCostLife
	end
	return {
		dps = dps,
		netRegen = netRegen,
		ehp = output.EHP or output.TotalEHP or 0,
		mana = output.Mana or 0,
		fireRes = output.FireResist or 75,
	}
end

function M.score(build, archetype, options)
	local phase = options.phase or "main"
	local weights = self.getWeights(archetype, phase)
	local stats = self.rawStats(build)

	local total = stats.dps * weights.dps
		+ math.max(0, stats.netRegen) * weights.regen * 1000
		+ stats.ehp * weights.ehp
		+ stats.mana * weights.mana

	if stats.fireRes < (archetype.minFireRes or 85) then
		total = total * 0.5
	end

	if options.requireRegen and stats.netRegen <= 0 then
		total = total * 0.01
	end

	-- Phase 2: retain phase-1 DPS progress (hard floor)
	if phase == "opposite" and options.phase1Floor then
		local floor = options.phase1Floor
		local dpsRetain = archetype.dpsRetainRatio or 0.92
		if stats.dps < floor.dps * dpsRetain then
			total = total * 0.001
		else
			-- Bonus for keeping more DPS than floor
			total = total + (stats.dps - floor.dps * dpsRetain) * 0.01
		end
		if stats.netRegen < (floor.netRegen or 0) then
			total = total * 0.5
		end
	end

	if archetype.bonusKeystones then
		local spec = build.spec
		for _, kid in ipairs(archetype.bonusKeystones) do
			if spec.allocNodes[kid] or spec.nodes[kid] then
				total = total * 1.02
			end
		end
	end

	return {
		total = total,
		dps = stats.dps,
		netRegen = stats.netRegen,
		ehp = stats.ehp,
		mana = stats.mana,
		fireRes = stats.fireRes,
		phase = phase,
	}
end

return M
