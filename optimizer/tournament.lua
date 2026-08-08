-- tournament.lua — Tournament selection (k-way) for GA

local M = {}

function M.select(population, k, rng)
	k = k or 5
	local best = nil
	for _ = 1, k do
		local idx = rng(1, #population)
		local candidate = population[idx]
		if not best or candidate.fitness > best.fitness then
		 best = candidate
		end
	end
	return best
end

return M
