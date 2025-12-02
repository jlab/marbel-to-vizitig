#!/usr/bin/env bash
set -euo pipefail
base_dir="$(pwd)"

name=$1
mkdir -p "$name/file_list_csv"



# CSV-Datei vorbereiten
: > "$name/file_list_csv/file_list.csv"



# Alle passenden FASTQ-Dateien finden
for r1 in "$name"/simulated_reads/group_*_sample*_R1.fastq.gz; do
    # Entsprechende R2-Datei
    r2="${r1/_R1.fastq.gz/_R2.fastq.gz}"

    # Prüfe, ob R2 existiert
    if [[ -f "$r2" ]]; then
        # Sample-Nummer extrahieren
        sample_num=$(echo "$r1" | grep -oP 'sample_\K[0-9]+')

        # Gruppe extrahieren (1 oder 2)
        group=$(echo "$r1" | grep -oP 'group_\K[12]')

        # Gruppencode A oder B
        if [[ "$group" == "1" ]]; then
            group_code="A"
        else
            group_code="B"
        fi

        # Schreibe Zeile in CSV
        echo "$base_dir/$r1,$base_dir/$r2,$group_code,$sample_num" >> "$name/file_list_csv/file_list.csv"
    fi
done
