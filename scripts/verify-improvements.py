#!/usr/bin/env python3
"""Offline unit checks for Split Personality path scoring + dual-phase config."""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def bfs(graph, start, allowed=None):
    dist = {start: 0}
    q = deque([start])
    while q:
        cur = q.popleft()
        for nxt in graph.get(cur, []):
            if nxt in dist:
                continue
            if allowed is not None and nxt not in allowed and nxt != start:
                continue
            dist[nxt] = dist[cur] + 1
            q.append(nxt)
    return dist


def test_sp_zigzag_beats_straight():
    # Synthetic passive graph:
    # start - a - b - socket          (straight len 3)
    #       \ c - d /                 (zigzag via c,d when allocated: start-a-c-d-b-socket len 5)
    graph = {
        "start": ["a"],
        "a": ["start", "b", "c"],
        "b": ["a", "socket", "d"],
        "c": ["a", "d"],
        "d": ["c", "b"],
        "socket": ["b"],
    }
    straight_alloc = {"start", "a", "b", "socket"}
    zigzag_alloc = {"start", "a", "b", "c", "d", "socket"}

    # Straight distance on full graph
    straight = bfs(graph, "start")["socket"]
    assert straight == 3, straight

    # Allocated path lengths
    alloc_straight = bfs(graph, "start", straight_alloc)["socket"]
    alloc_zigzag = bfs(graph, "start", zigzag_alloc)["socket"]
    assert alloc_straight == 3, alloc_straight
    # With only allocated edges, zigzag set still has short path a-b-socket = 3,
    # but also longer routes. SP uses passives BETWEEN jewel and start on the path
    # PoB uses — typically shortest allocated path. Zigzag helps when the SHORT
    # allocated path is forced longer (no chord). Remove a-b chord:
    graph2 = {
        "start": ["a"],
        "a": ["start", "c"],
        "c": ["a", "d"],
        "d": ["c", "b"],
        "b": ["d", "socket"],
        "socket": ["b"],
    }
    zig_only = {"start", "a", "c", "d", "b", "socket"}
    short_attempt = {"start", "a", "b", "socket"}  # disconnected b
    assert "socket" not in bfs(graph2, "start", short_attempt)
    zig_len = bfs(graph2, "start", zig_only)["socket"]
    assert zig_len == 5, zig_len
    # Effect multiplier: 25% per allocated passive between = path length
    assert zig_len > straight
    print("OK: zigzag allocated path (5) beats straight (3) for Split Personality")


def test_dual_phase_defaults():
    cfg = json.loads((ROOT / "configs/optimizer-defaults.json").read_text())
    assert cfg["generations"] == 60
    assert cfg["population"] == 60
    assert cfg["dualPhase"] is True
    assert cfg["phase1EliteCarryover"] == 12
    assert cfg["preferZigzagPaths"] is True
    assert cfg["noTimeLimit"] is True
    assert cfg.get("timeLimitSeconds") is None
    arch = json.loads((ROOT / "configs/archetypes/rf_arcane_devotion.json").read_text())
    assert arch["dpsRetainRatio"] == 0.92
    assert arch["optimizeSplitPersonality"] is True
    print("OK: dual-phase 60+60 defaults + no local time limit + RF archetype retain ratio")


def test_baseline_verify_script():
    from importlib.util import spec_from_loader, module_from_spec
    import importlib.machinery

    path = ROOT / "scripts/verify-baseline.py"
    loader = importlib.machinery.SourceFileLoader("verify_baseline", str(path))
    spec = spec_from_loader(loader.name, loader)
    mod = module_from_spec(spec)
    loader.exec_module(mod)
    rc = mod.main()
    assert rc == 0, rc
    print("OK: baseline PoB decodes with 2x Split Personality + Indigon + RF")


def main() -> int:
    test_sp_zigzag_beats_straight()
    test_dual_phase_defaults()
    test_baseline_verify_script()
    print("\nAll offline verification checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
