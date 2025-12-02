#!/usr/bin/env python3
import argparse
import sqlite3
from collections import defaultdict
import json
# Wir nutzen deinen vorhandenen Parser
from gfa2vizitig import parse_gfa


def build_coverage_map(gfa_path: str):
    """
    Lies dbg_g.gfa und baue eine Map:
      (source_id, target_id) -> "BASE:cov" oder "BASE1:cov1,BASE2:cov2"
    basierend auf den L-Tags 'L:<from_or>:<to_id>:<to_or>:<base>:<cov>'.
    """
    sequences, metadata, links, abundance, sums = parse_gfa(gfa_path, color_by=[])

    edge_cov = defaultdict(list)  # (src, dst) -> [ "G:5", "C:4", ... ]

    for src, tokens in links.items():
        src_int = int(src)
        for tok in tokens:
            # Erwartetes Format: "L:<from_or>:<to_id>:<to_or>[:<base>:<cov>]"
            parts = tok.split(":")
            # parts[0] = "L"
            # parts[1] = from_or
            # parts[2] = to_id
            # parts[3] = to_or
            if len(parts) >= 6:
                to_id = int(parts[2])
                base = parts[4]
                cov = parts[5]
                cov_str = f"{base}:{cov}"
                edge_cov[(src_int, to_id)].append(cov_str)
            else:
                # kein Coverage für diese Kante
                continue

    # Für jede Kante einen zusammengefassten String bauen
    merged = {
        (src, dst): ",".join(covs)
        for (src, dst), covs in edge_cov.items()
    }
    return merged

def write_coverage_to_db(db_path: str, cov_map: dict[tuple[int, int], str]):
    """
    Schreibe die Coverage aus cov_map in edge_data2 der Vizitig-DB.

    cov_map: (source, target) -> "G:5" oder "G:5,C:4"
    """
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # 1) Prüfen, ob schon edge_coverage eingetragen ist
    cur.execute("SELECT 1 FROM edge_data2 WHERE key = 'edge_coverage' LIMIT 1;")
    already = cur.fetchone()
    if already is not None:
        print("[INFO] edge_coverage already present in edge_data2 – skipping update.")
        conn.close()
        return

    # 2) Falls noch nichts da ist: ggf. aufräumen (nur zur Sicherheit)
    cur.execute("DELETE FROM edge_data1 WHERE key = 'edge_coverage';")
    cur.execute("DELETE FROM edge_data2 WHERE key = 'edge_coverage';")

    # 3) Für jede (source,target)-Kante die passende edge-id suchen und schreiben
    for (src, dst), cov_str in cov_map.items():
        cur.execute(
            "SELECT id FROM edges1 WHERE source = ? AND target = ?;",
            (src, dst),
        )
        rows = cur.fetchall()
        for (edge_id,) in rows:
            json_value = json.dumps(cov_str)
            cur.execute(
                "INSERT INTO edge_data2(id, key, value) VALUES (?, 'edge_coverage', ?);",
                (edge_id, json_value),
            )

    conn.commit()
    conn.close()


def main():
    ap = argparse.ArgumentParser(
        description="Trage Edge-Coverage aus dbg-style GFA in eine Vizitig-DB ein."
    )
    ap.add_argument(
        "gfa",
        help="Pfad zur dbg_g.gfa (mit 'edge coverage:' in den S-Zeilen)",
    )
    ap.add_argument(
        "db",
        help="Pfad zur Vizitig-Datenbank, z.B. ~/.vizitig/data/<name>.db",
    )
    args = ap.parse_args()

    print(f"[INFO] Lese Coverage aus {args.gfa} ...")
    cov_map = build_coverage_map(args.gfa)
    print(f"[INFO] {len(cov_map)} Kanten mit Coverage gefunden.")

    print(f"[INFO] Schreibe Coverage in {args.db} ...")
    write_coverage_to_db(args.db, cov_map)
    print("[INFO] Fertig.")


if __name__ == "__main__":
    main()
