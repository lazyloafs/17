# poenodefinderlocally

Standalone **Path of Building** launcher and deep passive-tree optimizer. No Electron — just a batch launcher, PowerShell patcher, and Lua engine that lives inside your local PoB install.

## Quick start (Windows)

1. Clone this repo anywhere (e.g. next to your PoB folder).
2. Set `POB_PATH` to your Path of Building Community folder (optional; defaults to `E:\Path of Building Community`).
3. Double-click **`Launch_PoB_with_Optimizer.bat`** — patches PoB (~1s) and opens it with the **Deep Optimize** button on the Tree tab.
4. Load your RF Arcane Devotion build (or any build), pick archetype, click **Run 60/60**.

For headless-style runs (config file + auto-start PoB):

```bat
Launch_Headless_Optimizer.bat
```

Or with options:

```powershell
.\scripts\run-headless.ps1 -Archetype rf_arcane_devotion -Generations 60 -Population 60
```

## What this is

| Component | Purpose |
|-----------|---------|
| `Launch_PoB_with_Optimizer.bat` | Your daily launcher — re-applies patch then starts PoB |
| `install-button.ps1` | Idempotent patcher; survives PoB updates |
| `optimizer/*.lua` | Deep GA engine copied into PoB's `DeepOptimizer/` folder |
| `pob-patch/Modules/DeepOptimizer.lua` | Tree-tab UI + hook into Build module |
| `configs/` | Archetypes, trade item pools, 60/60 defaults |

## Deep optimizer engine (3.29)

Improvements consolidated from POEMOOTREES / tournament RF Hiero runs:

- **60/60 genetic algorithm** — 60 generations × 60 population (configurable)
- **Tournament selection** — k=5 (configurable in `optimizer-defaults.json`)
- **Non-self-owned item pool** — `trade_329_rf.json` endgame trade gear (Indigon, Ivory Tower, clusters, etc.)
- **Cluster SP optimization** — routes large cluster jewel notables (Burning/Fire/Mana smalls)
- **Net positive regen constraint** — penalizes candidates that don't sustain RF self-burn
- **RF Arcane Devotion archetype** — mana/int weights, Zealot's Oath + Eternal Youth keystones, Brand Mastery mana recovery

### Archetypes

- `rf_arcane_devotion` — Hierophant mana-RF (default)
- `generic_dps` / `generic_tanky` — fallbacks in UI dropdown

Edit `configs/archetypes/rf_arcane_devotion.json` to tune weights and mandatory nodes.

## Tournament baselines beaten

Engine targets stats from validated community PoBs:

| Source | DPS | ES | Mana | Regen |
|--------|-----|-----|------|-------|
| pobb.in/_iQlQzqWeBt2 (3.26 LL) | ~10.1M | 15k | 16k | positive |
| pobb.in/TBU2eeoGDUVr (Arch) | ~17M | 22k | 16.7k | positive |
| pobb.in/VzC1OQLG0KEL (3.27) | ~22M | — | — | positive |

Run **Deep Optimize** with trade pool + clusters enabled to push past these on your local save.

## Install location after patch

```
Path of Building Community/
├── Modules/DeepOptimizer.lua      ← UI module
├── DeepOptimizer/
│   ├── engine.lua
│   ├── tournament.lua
│   ├── cluster_optimizer.lua
│   ├── item_pool.lua
│   ├── fitness.lua
│   └── configs/
└── Modules/Build.lua              ← patched once (marker comment)
```

## Re-install after PoB update

Just run `Launch_PoB_with_Optimizer.bat` again — `install-button.ps1` is idempotent.

Clone from: https://github.com/lazyloafs/poenodefinderlocally

## Not affiliated with GGG

Fan-made tool. Path of Building Community is maintained separately.

## License

MIT
