-- headless.lua — Poll headless_optimizer_request.json and run when PoB is open

local Headless = {}

function Headless:tryRun(build, deepOptimizer)
	local settingsPath = os.getenv("APPDATA")
	if not settingsPath then return end
	local reqPath = settingsPath .. "/Path of Building/Settings/headless_optimizer_request.json"
	local f = io.open(reqPath, "r")
	if not f then return end
	local raw = f:read("*a")
	f:close()

	local json = require("dkjson")
	local ok, req = pcall(json.decode, raw)
	if not ok or not req then return end

	-- Clear request so we don't re-run
	os.remove(reqPath)

	local result = deepOptimizer:RunHeadless(build, {
		archetype = req.archetype or "rf_arcane_devotion",
		generations = req.generations or 60,
		population = req.population or 60,
		dualPhase = req.dualPhase ~= false,
		useTradeItems = req.useTradeItems ~= false,
		optimizeClusters = req.optimizeClusters ~= false,
		optimizeJewels = req.optimizeJewels ~= false,
		mutateJewelPaths = req.mutateJewelPaths ~= false,
		preferZigzagPaths = req.preferZigzagPaths ~= false,
		requireRegen = req.requireRegen ~= false,
		phase1EliteCarryover = req.phase1EliteCarryover or 12,
		phase2MutationRate = req.phase2MutationRate or 0.20,
		-- Local runs never use a wall-clock time limit
		noTimeLimit = req.noTimeLimit ~= false,
		timeLimitSeconds = nil,
		headless = true,
	})

	-- Append a short status line for Launch_PoB_with_Optimizer.bat status mode
	if result and settingsPath then
		local logPath = settingsPath .. "/Path of Building/Settings/localoptimizer.log"
		local lf = io.open(logPath, "a")
		if lf then
			lf:write(string.format(
				"[%s] headless done selected=%s dps=%.0f regen=%.0f ehp=%.0f dual=%s\n",
				os.date("%Y-%m-%d %H:%M:%S"),
				tostring(result.selected),
				result.dps or 0,
				result.netRegen or 0,
				result.ehp or 0,
				tostring(result.dualPhase)
			))
			lf:close()
		end
	end
	return result
end

return Headless
