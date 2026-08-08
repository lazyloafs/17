# localoptimizer

Standalone **Path of Building** launcher and deep passive-tree optimizer for local saves. No Electron — batch launcher + PowerShell patcher + Lua engine inside PoB.

## Quick start

1. Clone: `git clone https://github.com/lazyloafs/localoptimizer`
2. Set `POB_PATH` if needed (default: `E:\Path of Building Community`)
3. Run **`Launch_PoB_with_Optimizer.bat`**

If the GitHub repo does not exist yet, create an empty public repo named `localoptimizer` under your account, then from this folder run:

```bat
powershell -ExecutionPolicy Bypass -File scripts\publish-to-github.ps1
```

(or `bash scripts/publish-to-github.sh` on Linux/macOS with `gh` auth).

### Launcher modes

| Command | What it does |
|---------|----------------|
| `Launch_PoB_with_Optimizer.bat` | Patch PoB + start (daily use) |
| `Launch_PoB_with_Optimizer.bat optimize` | Patch + queue **60+60 dual-phase** optimize + start PoB |
| `Launch_PoB_with_Optimizer.bat verify` | Decode/validate baseline + open PoB code for before/after |
| `Launch_PoB_with_Optimizer.bat status` | Show queued request + last result + recent log |
| `Put_Launcher_on_Desktop.bat` | Place **Launch PoB with Optimizer.bat** on your Desktop |

If a console titled **NSGA-II Opt DPS** shows `Time budget: 600 seconds`, that is a **different** optimizer. Use the Desktop / `Launch_PoB_with_Optimizer.bat` launcher from this repo instead.

## Dual-phase 60+60 optimizer

1. **Phase 1 (60 gens × 60 pop)** — Main objective: max DPS / mana scaling for RF Arcane Devotion
2. **Phase 2 (60 gens × 60 pop)** — Opposite objective: max regen + eHP, **retaining ≥92% phase-1 DPS**

Phase 2 is seeded from the top **12 phase-1 elites** so first-objective progress is not lost. If phase 2 drops below the DPS floor, the engine keeps the phase-1 tree.

**Local Deep Optimize has no wall-clock time limit** — unlike cloud/web optimizers, the button runs every generation to completion (`noTimeLimit: true`).

## Complete tree mutation

- Connected growth from class start (no disconnected random nodes)
- Connectivity repair after crossover/mutation
- Exact skill-point budget enforcement
- Cluster path reroutes
- **Zigzag extension** toward distant jewel sockets

## Split Personality repositioning

PoE rule: *25% increased effect per Allocated Passive Skill between the jewel and your class start.*

The optimizer:

1. Scores every allocated jewel socket by **allocated-path length** (and straight distance)
2. Prefers **zigzag** when the allocated path is longer than the shortest path
3. Moves Split Personality jewels onto the farthest sockets
4. Mutates tree corridors to lengthen SP paths when beneficial

## Other engine features

- Tournament selection (k=5), elite carryover, configurable phase-2 mutation rate
- Non-self-owned trade item pool (`trade_329_rf.json`)
- Net positive regen constraint after RF self-burn
- Writes `%APPDATA%\Path of Building\Settings\localoptimizer_last_result.json`

## Verification baseline

```bat
Launch_PoB_with_Optimizer.bat verify
```

Or:

```bat
python scripts\verify-baseline.py builds\baseline_rf_arcane_devotion.pob.txt
```

Import the baseline in PoB, note DPS + regen, run **Run 60+60**, then compare `localoptimizer_last_result.json`.

## In PoB

Tree tab → **Deep Optimize** → configure → **Run 60+60**

Options: trade pool, clusters, dual phase, Split Personality reposition, prefer zigzag.

## License

MIT
