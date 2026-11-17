"""Build the Secret League roster asset from the supplied 2025 sheets.

All roster positions, costs and special rules are transcribed in secret_2025.tsv.
Run from the repository root: python3 tooling/build_secret_rosters.py
"""

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHEETS = ROOT / "tooling" / "secret_2025.tsv"
ASSET = ROOT / "assets" / "rosters.json"


def main():
    rosters = json.loads(ASSET.read_text())
    vanilla = [r for r in rosters if not r["secret"]]
    result = {}
    with SHEETS.open(newline="") as handle:
        for record in csv.reader(handle, delimiter="|"):
            if not record or record[0].startswith("#"):
                continue
            kind, *cells = [cell.strip() for cell in record]
            if kind == "T":
                name, _reference_name, tier, leagues, rules, apothecary = cells
                result[name] = {
                    "name": name,
                    "secret": True,
                    "leagues": leagues.split(";") if leagues else [],
                    "specialRules": rules.split(";") if rules else [],
                    "apothecary": apothecary == "Y",
                    "tier": int(tier) if tier.isdecimal() else tier,
                    "positions": [],
                }
            elif kind == "P":
                (team, title, qty, tags, price, ma, st, ag, pa, av, skills,
                 primary, secondary) = cells
                result[team]["positions"].append({
                    "name": title,
                    "max": int(qty),
                    "tags": [tag.strip() for tag in tags.split(",")],
                    "ma": ma,
                    "st": st,
                    "ag": ag,
                    "pa": pa,
                    "av": av,
                    "skills": [s.strip() for s in skills.split(";") if s.strip()],
                    "primary": primary,
                    "secondary": secondary,
                    "price": int(price) * 1000,
                })
            elif kind == "C":
                team, positions = cells
                result[team]["captainPositions"] = positions.split(";")
            elif kind == "R":
                team, reroll = cells
                result[team]["rerollPrice"] = int(reroll) * 1000
            elif kind == "B":
                team, big_guy_limit = cells
                result[team]["maxBigGuys"] = int(big_guy_limit)
            elif kind == "N":
                team, note = cells
                result[team].setdefault("notes", []).append(note)
            elif kind == "O":
                team, key, label, choices = cells
                result[team].setdefault("creationOptions", []).append({
                    "key": key, "label": label, "choices": choices.split(";"),
                })
            else:
                raise ValueError(f"Unknown record kind: {kind}")
    for name, roster in result.items():
        if not roster["positions"]:
            raise ValueError(f"Missing positions: {name}")
    ASSET.write_text(json.dumps(vanilla + [result[k] for k in sorted(result)], indent=2) + "\n")
    print(f"Wrote {len(vanilla)} vanilla and {len(result)} Secret League rosters")


if __name__ == "__main__":
    main()
