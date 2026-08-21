#!/usr/bin/env python3
"""Build the compact DesktopWorm graph from the OpenWorm c302 dataset."""

from __future__ import annotations

import csv
import json
import re
import sys
import urllib.request
from pathlib import Path

C302_REV = "6cd861f8ca4d3241ee9cf4627884caa930dab53c"
BASE = f"https://raw.githubusercontent.com/openworm/c302/{C302_REV}/c302/data"
FILES = ("herm_full_edgelist.csv", "owmeta_cache.json")


def fetch(cache_dir: Path, name: str) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    destination = cache_dir / name
    if not destination.exists():
        urllib.request.urlretrieve(f"{BASE}/{name}", destination)
    return destination


def normalize_cell(name: str, neurons: set[str]) -> str:
    name = name.strip()
    if name in neurons:
        return name
    candidate = re.sub(r"^([A-Z]+)0([1-9])$", r"\1\2", name)
    return candidate if candidate in neurons else name


def normalize_muscle(name: str) -> str:
    match = re.fullmatch(r"([dv])BWM([LR])(\d+)", name.strip())
    if not match:
        return name.strip()
    surface, side, number = match.groups()
    prefix = "MD" if surface == "d" else "MV"
    return f"{prefix}{side}{int(number):02d}"


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    cache = root / "work" / "c302-source"
    output = root / "Sources" / "DesktopWorm" / "Resources" / "connectome.json"

    edge_path = fetch(cache, FILES[0])
    meta_path = fetch(cache, FILES[1])
    metadata = json.loads(meta_path.read_text())

    names = sorted(metadata["neuron_info"])
    if len(names) != 302:
        raise RuntimeError(f"Expected 302 neurons, found {len(names)}")
    neuron_set = set(names)
    muscles = sorted(metadata["muscle_info"])
    neuron_index = {name: index for index, name in enumerate(names)}
    muscle_index = {name: index for index, name in enumerate(muscles)}

    neurons = []
    inhibitory = set()
    for name in names:
        entry = metadata["neuron_info"][name]
        roles = entry[1]
        transmitters = entry[3]
        if any("GABA" in transmitter.upper() for transmitter in transmitters):
            inhibitory.add(name)
        neurons.append(
            {
                "id": name,
                "roles": roles,
                "transmitters": transmitters,
            }
        )

    edges = []
    muscle_edges = []
    with edge_path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            source = normalize_cell(row["Source"], neuron_set)
            target = normalize_cell(row["Target"], neuron_set)
            weight = int(row["Weight"])
            kind = row["Type"].strip().lower()
            if source in neuron_index and target in neuron_index:
                edges.append(
                    {
                        "source": neuron_index[source],
                        "target": neuron_index[target],
                        "weight": weight,
                        "kind": kind,
                        "sign": -1 if kind == "chemical" and source in inhibitory else 1,
                    }
                )
                continue

            muscle = normalize_muscle(target)
            if source in neuron_index and muscle in muscle_index:
                muscle_edges.append(
                    {
                        "source": neuron_index[source],
                        "target": muscle_index[muscle],
                        "weight": weight,
                        "sign": -1 if source in inhibitory else 1,
                    }
                )

    payload = {
        "dataset": "OpenWorm c302 / Cook et al. 2019 hermaphrodite connectome",
        "sourceRevision": C302_REV,
        "neurons": neurons,
        "edges": edges,
        "muscles": muscles,
        "muscleEdges": muscle_edges,
    }
    output.write_text(json.dumps(payload, separators=(",", ":")))
    print(
        f"wrote {output}: {len(neurons)} neurons, {len(edges)} neural edges, "
        f"{len(muscles)} muscles, {len(muscle_edges)} neuromuscular edges"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise
