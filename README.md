# localoptimizer

Standalone **Path of Building** launcher and deep passive-tree optimizer for local saves. No Electron — batch launcher + PowerShell patcher + Lua engine inside PoB.

## Quick start

1. Clone this repo (or use your existing checkout)
2. Set `POB_PATH` if needed (default: `E:\Path of Building Community`)
3. Run **`Install_Desktop_Shortcuts.bat`** to copy launchers to your Desktop
4. Double-click **`Opt_DPS.bat`** or **`Opt_Tank.bat`** on your Desktop

## Desktop launchers

| File | What it does |
|------|----------------|
| `Opt_DPS.bat` | Patch PoB + queue **max DPS** optimize (60 gens) + launch PoB |
| `Opt_Tank.bat` | Patch PoB + queue **max survivability** optimize (regen/eHP) + launch PoB |
| `Launch_PoB_with_Optimizer.bat` | Patch PoB + start (daily use) |
| `Install_Desktop_Shortcuts.bat` | Copy the above `.bat` files to your Desktop |

## In PoB — Tree tab buttons

After the first run (patch installs automatically), open any build and go to the **Tree** tab. You'll see two buttons next to the power report controls:

- **Opt DPS** — one-click deep optimize for maximum damage
- **Opt Tank** — one-click deep optimize for regen and effective HP (keeps your current DPS floor)

Progress prints to the PoB console (`Ctrl+` backtick in some builds, or check PoB logs).

## Launcher modes

| Command | What it does |
|---------|----------------|
| `Launch_PoB_with_Optimizer.bat` | Patch PoB + start (daily use) |
| `Launch_PoB_with_Optimizer.bat dps` | Patch + queue Opt DPS + start PoB |
| `Launch_PoB_with_Optimizer.bat tank` | Patch + queue Opt Tank + start PoB |
| `Launch_PoB_with_Optimizer.bat optimize` | Patch + queue **60+60 dual-phase** + start PoB |

## Dual-phase 60+60 optimizer

1. **Phase 1 (60 gens × 60 pop)** — Main objective: max DPS / mana scaling
2. **Phase 2 (60 gens × 60 pop)** — Opposite objective: max regen + eHP, **retaining ≥92% phase-1 DPS**

Use `Launch_PoB_with_Optimizer.bat optimize` for dual-phase, or the single-phase Desktop buttons for faster one-objective runs.

## Other engine features

- Tournament selection (k=5), full tree mutation, cluster SP routing
- **Split Personality repositioning** — farthest sockets from class start; zigzag path scoring
- Non-self-owned trade item pool (`trade_329_rf.json`)
- Net positive regen constraint for tank optimize

## Verification baseline

Import `builds/baseline_rf_arcane_devotion.pob.txt` in PoB before optimizing. Compare Total DPS and net regen after optimize.

## License

MIT
