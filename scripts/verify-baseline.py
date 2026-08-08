#!/usr/bin/env python3
"""Verify RF Arcane Devotion baseline PoB code used by localoptimizer."""
from __future__ import annotations

import base64
import re
import sys
import zlib
from pathlib import Path


REQUIRED = [
    ("Split Personality", 2),
    ("Indigon", 1),
    ("Righteous Fire", 1),
]


def decode_pob(text: str) -> str:
    lines = [l for l in text.splitlines() if l.strip() and not l.strip().startswith("#")]
    code = "".join(lines).strip()
    pad = (-len(code)) % 4
    code += "=" * pad
    return zlib.decompress(base64.urlsafe_b64decode(code)).decode("utf-8", errors="replace")


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "builds/baseline_rf_arcane_devotion.pob.txt")
    if not path.exists():
        print(f"FAIL: baseline not found: {path}")
        return 1

    raw = path.read_text(encoding="utf-8", errors="replace")
    try:
        xml = decode_pob(raw)
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL: could not decode PoB code: {exc}")
        return 1

    print(f"OK: decoded {path.name} ({len(xml)} chars)")
    ok = True
    for name, min_count in REQUIRED:
        count = len(re.findall(re.escape(name), xml, flags=re.I))
        status = "OK" if count >= min_count else "FAIL"
        if status == "FAIL":
            ok = False
        print(f"  {status}: {name} x{count} (need >={min_count})")

    nodes_m = re.search(r'nodes="([^"]+)"', xml)
    if nodes_m:
        n = len(nodes_m.group(1).split(","))
        print(f"  OK: allocated passive nodes = {n}")
    else:
        print("  FAIL: no nodes= attribute")
        ok = False

    sockets = re.findall(r'<Socket\s+itemId="(\d+)"\s+nodeId="(\d+)"', xml)
    print(f"  OK: jewel sockets = {len(sockets)} {sockets}")

    sp_ids = set()
    for m in re.finditer(r'<Item[^>]*id="(\d+)"[^>]*>(.*?)</Item>', xml, flags=re.S):
        if re.search(r"Split Personality", m.group(2), flags=re.I):
            sp_ids.add(m.group(1))
    sp_sockets = [(iid, nid) for iid, nid in sockets if iid in sp_ids]
    print(f"  OK: Split Personality socket placements = {sp_sockets}")
    if len(sp_sockets) < 2:
        print("  WARN: expected 2 Split Personality jewels socketed")

    # Tree version / class hints
    if "Hierophant" in xml or 'ascendClassId="2"' in xml:
        print("  OK: Hierophant / ascendancy present")
    if "treeVersion=" in xml:
        ver = re.search(r'treeVersion="([^"]+)"', xml)
        if ver:
            print(f"  OK: treeVersion = {ver.group(1)}")

    print()
    print("Verification checklist for Launch_PoB_with_Optimizer.bat optimize:")
    print("  1. Import this baseline in PoB")
    print("  2. Note Total DPS + net ES/life regen after RF burn")
    print("  3. Run Deep Optimize (60 main + 60 opposite, retain DPS)")
    print("  4. Confirm SP jewels moved toward longer allocated paths from start")
    print("  5. Compare localoptimizer_last_result.json phase1 vs phase2")
    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
