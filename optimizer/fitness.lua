-- fitness.lua — Multi-objective fitness using PoB calcs (DPS, regen, eHP, resist floor)

local M = {}

function M.score(build, archetype, options)
	local output = build.calcsTab.mainOutput
	local weights = archetype.weights or {
		dps = 1.0,
		regen = 0.35,
		ehp = 0.0001,
		mana = 0.002,
		fireRes = 0.5,
	}

	local dps = output.TotalDPS or output.CombinedDPS or 0
	local lifeRegen = output.LifeRegenRecovery or 0
	local esRegen = output.ESRegenRecovery or 0
	local netRegen = lifeRegen + esRegen

	-- RF self-burn: approximate net regen after RF cost
	local rfCost = output.RFCost or output.LifeReserved or 0
	if output.RFCostLife then
		netRegen = netRegen - output.RFCostLife
	end

	local ehp = output.EHP or output.TotalEHP or 0
	local mana = output.Mana or 0
	local fireRes = output.FireResist or 75

	local total = dps * weights.dps
		+ math.max(0, netRegen) * weights.regen * 1000
		+ ehp * weights.ehp
		+ mana * weights.mana

	if fireRes < (archetype.minFireRes or 85) then
		total = total * 0.5
	end

	if options.requireRegen and netRegen <= 0 then
		total = total * 0.01
	end

	-- Archetype-specific bonuses from tournament findings
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
		dps = dps,
		netRegen = netRegen,
		ehp = ehp,
		mana = mana,
		fireRes = fireRes,
	}
end

return M
