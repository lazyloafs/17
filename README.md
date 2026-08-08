# localoptimizer

Standalone **Path of Building** launcher and deep passive-tree optimizer for local saves. No Electron — batch launcher + PowerShell patcher + Lua engine inside PoB.

## Quick start

1. Clone: `git clone https://github.com/lazyloafs/localoptimizer`
2. Set `POB_PATH` if needed (default: `E:\Path of Building Community`)
3. Run **`Launch_PoB_with_Optimizer.bat`**

### Launcher modes

| Command | What it does |
|---------|----------------|
| `Launch_PoB_with_Optimizer.bat` | Patch PoB + start (daily use) |
| `Launch_PoB_with_Optimizer.bat optimize` | Patch + queue **60+60 dual-phase** optimize + start PoB |
| `Launch_PoB_with_Optimizer.bat verify` | Patch + open baseline PoB code for before/after comparison |

## Dual-phase 60+60 optimizer

1. **Phase 1 (60 gens × 60 pop)** — Main objective: max DPS / mana scaling for RF Arcane Devotion
2. **Phase 2 (60 gens × 60 pop)** — Opposite objective: max regen + eHP, **retaining ≥92% phase-1 DPS**

Seeded from phase-1 elites so progress is not lost.

## Other engine features

- Tournament selection (k=5), full tree mutation, cluster SP routing
- **Split Personality repositioning** — farthest sockets from class start; zigzag path scoring
- Non-self-owned trade item pool (`trade_329_rf.json`)
- Net positive regen constraint after RF self-burn

## Verification baseline

Import `builds/baseline_rf_arcane_devotion.pob.txt` in PoB before running **Run 60+60** on the Tree tab. Compare Total DPS and net regen after optimize.

## In PoB

Tree tab → **Deep Optimize** → configure → **Run 60+60**

Options: trade pool, clusters, dual phase, Split Personality reposition.

## License

MIT
