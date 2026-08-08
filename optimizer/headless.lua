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

	deepOptimizer:RunHeadless(build, {
		archetype = req.archetype or "rf_arcane_devotion",
		generations = req.generations or 60,
		population = req.population or 60,
		dualPhase = req.dualPhase ~= false,
		useTradeItems = req.useTradeItems ~= false,
		optimizeClusters = req.optimizeClusters ~= false,
		optimizeJewels = req.optimizeJewels ~= false,
		mutateJewelPaths = req.mutateJewelPaths ~= false,
		requireRegen = req.requireRegen ~= false,
		headless = true,
	})
end

return Headless
