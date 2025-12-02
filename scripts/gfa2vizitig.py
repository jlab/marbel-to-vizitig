#!/usr/bin/env python3
import re
import argparse
import ast
from collections import defaultdict

# ---------- helpers for edge coverage parsing ----------

_RE_S_WITH_COV = re.compile(
    r'^S\t(\S+)\t(\S+)\t.*edge coverage:\s*(.*?)\s*\|\s*(.*)\s*$'
)
_RE_S_MIN = re.compile(r'^S\t(\S+)\t(\S+)(?:\t.*)?$')
_RE_L = re.compile(r'^L\t(\S+)\t([+-])\t(\S+)\t([+-])\t(\S+)\s*$')

def _parse_side_counts(side_str: str):
    """
    Parse a side coverage string like 'A: 0, C: 0, G: 5, T: 0'.
    Return only non-zero items in A,C,G,T order: [('G',5)].
    """
    side_str = side_str.strip()
    m = re.findall(r'([ACGT]):\s*([0-9]+)', side_str)
    d = {b: int(v) for b, v in m}
    out = []
    for b in ['A', 'C', 'G', 'T']:
        v = d.get(b, 0)
        if v != 0:
            out.append((b, v))
    return out

# -------------------------------------------------------


def parse_gfa(input_path, color_by):
    """
    Parse a dbg-style GFA and extract:
      - sequences: {unitig_id: sequence}
      - metadata:  {unitig_id: [ list_per_color_mode ]} (each entry is a list of samples)
      - links:     {unitig_id: list of extended L tokens}
                   where each link is 'L:<from_orient>:<to_id>:<to_orient>:<base>:<coverage>'
                   (base/coverage optional if absent)
    Also returns empty 'abundance' and 'sums' to keep your original interface stable.
    """
    sequences = {}
    metadata = defaultdict(list)
    abundance = {}
    sums = {}

    # Temporary storage
    # coverage queues per node & side: node_cov[node]['+'] = [(base,cov), ... RIGHT], '-' for LEFT
    node_cov = defaultdict(lambda: {'+': [], '-': []})
    # Collect raw L records in order per from_id
    raw_links = defaultdict(list)

    with open(input_path, 'r') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('H'):
                continue

            # S line with edge coverage present
            mS = _RE_S_WITH_COV.match(line)
            if mS:
                sid, seq, left_str, right_str = mS.group(1), mS.group(2), mS.group(3), mS.group(4)
                sequences[sid] = seq

                # parse metadata lists for requested color_by keys from the 'comment' part
                comment = line.split('\t', 3)[-1]
                for color_mode in color_by:
                    # allow keys with spaces, e.g. "mapped IDs"
                    m = re.search(rf'{re.escape(color_mode)}:\s*(\[[^\[\]]*\])', comment)
                    samples = []
                    if m:
                        list_str = m.group(1)
                        try:
                            samples = ast.literal_eval(list_str)
                        except Exception:
                            samples = []
                    metadata[sid].append(samples)

                # coverage queues
                node_cov[sid]['-'] = _parse_side_counts(left_str)
                node_cov[sid]['+'] = _parse_side_counts(right_str)
                continue

            # S line without edge coverage (fallback)
            mS2 = _RE_S_MIN.match(line)
            if mS2:
                sid, seq = mS2.group(1), mS2.group(2)
                sequences[sid] = seq
                # still try to parse metadata from comment if present
                if '\t' in line:
                    parts = line.split('\t', 3)
                    comment = parts[3] if len(parts) >= 4 else ""
                else:
                    comment = ""
                for color_mode in color_by:
                    m = re.search(rf'{re.escape(color_mode)}:\s*(\[[^\[\]]*\])', comment)
                    samples = []
                    if m:
                        list_str = m.group(1)
                        try:
                            samples = ast.literal_eval(list_str)
                        except Exception:
                            samples = []
                    metadata[sid].append(samples)
                # empty coverage queues remain
                continue

            # L line
            mL = _RE_L.match(line)
            if mL:
                from_id, from_or, to_id, to_or, overlap = mL.group(1), mL.group(2), mL.group(3), mL.group(4), mL.group(5)
                raw_links[from_id].append({
                    'from_or': from_or,
                    'to_id':   to_id,
                    'to_or':   to_or,
                    'overlap': overlap
                })
                continue

    # Now assign coverage to each outgoing link in order using the correct side
    links = defaultdict(list)
    for from_id, entries in raw_links.items():
        for e in entries:
            side = e['from_or']  # '+' -> RIGHT, '-' -> LEFT
            queue = node_cov[from_id][side]
            base, cov = (None, None)
            if queue:
                base, cov = queue.pop(0)
            # Build extended L token (include base/cov only if present)
            if base is not None and cov is not None:
                tok = f"L:{e['from_or']}:{e['to_id']}:{e['to_or']}:{base}:{cov}"
            else:
                tok = f"L:{e['from_or']}:{e['to_id']}:{e['to_or']}"
            links[from_id].append(tok)

    return sequences, metadata, links, abundance, sums


def parse_gaf(gaf_path):
    """
    Read GAF and map transcript IDs to node IDs (list of str).
    """
    transcript_to_sids = {}
    with open(gaf_path, 'r') as gaf_file:
        for line in gaf_file:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            # transcript_id and path are the first and 6th fields (0, 5)
            parts = line.split('\t')
            if len(parts) < 6:
                continue
            transcript_id = parts[0]
            path = parts[5]
            sids = re.findall(r'\d+', path)
            transcript_to_sids[transcript_id] = sids
    return transcript_to_sids


def write_transcript_fasta(transcript_to_sids, sequences, output_path):
    """
    Write a FASTA per transcript path (utility; unchanged).
    """
    with open(output_path, 'w') as out_fasta:
        for transcript_id, sids in transcript_to_sids.items():
            for sid in sids:
                seq = sequences.get(sid)
                if seq:
                    out_fasta.write(f'>|XX_{transcript_id}|:0-0(unknown)\n{seq}\n')
                else:
                    print(f"{sid} existiert in sequences nicht")


def write_fasta_unitig(out, sid, sequences, links):
    """
    Write one FASTA record: header + sequence.
    Header carries extended L tokens with base/coverage if known.
    """
    header_parts = [f">{sid} genes: GENE0"]
    header_parts += links.get(sid, [])
    out.write(' '.join(header_parts) + '\n')
    out.write(sequences[sid] + '\n')


def write_sample_fas(output_dir, color_by_index, color_key, sequences, metadata, links):
    """
    For each color (e.g., sample / gene / OG), write a FASTA with all unitigs carrying that color.
    """
    from os import makedirs
    from os.path import join, exists
    if not exists(output_dir):
        makedirs(output_dir)

    color_to_unitigs = defaultdict(list)
    for sid, colors_all_modes in metadata.items():
        # pick the list for this color mode index
        colors = colors_all_modes[color_by_index] if color_by_index < len(colors_all_modes) else []
        for color in colors:
            color_to_unitigs[color].append(sid)

    for color, sids in color_to_unitigs.items():
        out_path = join(output_dir, f"{color_key}_{color}.fa")
        with open(out_path, 'w') as out:
            for sid in sids:
                write_fasta_unitig(out, sid, sequences, links)


def write_bcalm_fa(output_path, sequences, links):
    """
    Write a bcalm-style FASTA where header tokens include L: links.
    Links are extended to carry base/coverage when available.
    """
    with open(output_path, 'w') as out:
        for sid in sequences:
            write_fasta_unitig(out, sid, sequences, links)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert dbg-style GFA to bcalm-like FASTA including per-edge coverage.")
    parser.add_argument("input_gfa", help="Pfad zur Eingabe-GFA-Datei")
    parser.add_argument("output_fa", help="Pfad zur Ausgabedatei (FASTA)")
    parser.add_argument("--sample_dir", default="samples", help="Ordner für pro-Color FASTA-Dateien")
    parser.add_argument("--color_by", nargs='*', default=["samples"], help="Keys im Kommentar, z. B. IDs \"mapped IDs\"")
    # parser.add_argument("output_transcript")
    # parser.add_argument("gaf_path")

    args = parser.parse_args()

    sequences, metadata, links, abundance, sums = parse_gfa(args.input_gfa, args.color_by)

    # Main FASTA (with extended L tokens)
    write_bcalm_fa(args.output_fa, sequences, links)

    # Per-color FASTAs
    for color_by_index in range(len(args.color_by)):
        write_sample_fas(args.sample_dir, color_by_index, args.color_by[color_by_index],
                         sequences, metadata, links)

    # If you later want transcript FASTA:
    # transcript_to_sids = parse_gaf(args.gaf_path)
    # write_transcript_fasta(transcript_to_sids, sequences, args.output_transcript)

    
    
    
    
