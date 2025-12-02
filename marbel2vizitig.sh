#!/usr/bin/env bash

set -euo pipefail

# project name 
name=$1

MARBEL="/home/nurgissa/anaconda3/envs/Praktikum_JLAB/bin/marbel"
DBG="/home/nurgissa/.cargo/bin/dbg"
VIZITIG="/home/nurgissa/anaconda3/envs/Praktikum_JLAB/bin/vizitig"
GRAPHALIGNER="/home/nurgissa/anaconda3/envs/Praktikum_JLAB/bin/GraphAligner"
DB="$HOME/.vizitig/data/${name}.db"



# parameters
# marbel
N_SPECIES=2
N_OGS=10
LIB_SIZE=1000
N_SAMPLES="2 2"
SEED=23

# dbg
K=20
MEM=10 # memory limit

# Erstellung von Projektordner 
echo "Erstellung von Projektordnerstrukutur für '$name'..."

mkdir -p "$name"
mkdir -p "$name/genes" # FASTA Dateien nach Genen
mkdir -p "$name/ogs" # FASTA Dateien nach Orthogruppen
mkdir -p "$name/graphs" # FASTA Dateien von dbg und vizitig

#marbel

if [ -d $name/simulated_reads ]
then
	echo "marbel dir already exists, continuing with next step"
else
	# marbel
	echo "generating marbel dataset..."
	$MARBEL \
		--n-species $N_SPECIES \
	        --n-orthogroups $N_OGS \
	        --library-size $LIB_SIZE \
	        --n-samples $N_SAMPLES \
	        --seed $SEED \
	        --outdir $name/simulated_reads \
	        --library-size-distribution negative_binomial \
	        --threads 26 \
	        --group-orthology-level very_high \
	        --error-model NextSeq
fi


# Erstellung von CSV-Datei für dbg
mkdir -p "$name/file_list_csv"


# make csv
/home/nurgissa/Projects/marbel-to-vizitig/3_make_list.sh $name

echo "CSV-Datei ist schon erstellt worden"


# dbg
export RUST_LOG=debug
echo "building debruijn graph with dbg..."
$DBG --csv $name/file_list_csv/file_list.csv \
     --memory $MEM \
     --out $name/graphs/dbg_g \
     --checkpoint \
     --format bin \
     --summarizer id-map-em \
     --gene-summary $name/simulated_reads/summary/gene_summary.csv \
     --transcriptome-reference $name/simulated_reads/summary/metatranscriptome_reference.fasta \
     -k $K \
     --stranded \
     --threads 26
echo "Erstellung von gfa-Datei aus cached-graphs"
$DBG --cached-graph "$name/graphs/dbg_g.graph.dbg" \
     --memory $MEM \
     --out $name/graphs/dbg_g \
     --checkpoint \
     --format gfa \
     --summarizer id-map-em \
     --gene-summary $name/simulated_reads/summary/gene_summary.csv \
     --transcriptome-reference $name/simulated_reads/summary/metatranscriptome_reference.fasta \
     -k $K \
     --stranded \
     --threads 26


echo "writing debruijn graph orthogoups with dbg..."
$DBG --cached-graph $name/graphs/dbg_g.graph.dbg \
    --memory $MEM \
    --out $name/graphs/dbg_o \
    --checkpoint \
    --format gfa \
    --summarizer id-map-em \
    --gene-summary $name/simulated_reads/summary/gene_summary.csv \
    --transcriptome-reference $name/simulated_reads/summary/metatranscriptome_reference.fasta \
    -k $K \
    --gene-to-og \
    --stranded \
    --threads 26

# gfa to vizitig with genes and then ogs
echo "running gfa2vizitig.py..."
python scripts/gfa2vizitig.py \
	$name/graphs/dbg_g.gfa \
	$name/graphs/dbg_g.fa \
	--sample_dir $name/genes \
        --color_by IDs "mapped IDs"

python scripts/gfa2vizitig.py \
	$name/graphs/dbg_o.gfa \
	$name/graphs/dbg_o.fa \
	--sample_dir $name/ogs \
        --color_by IDs "mapped IDs"




# add graph to vizitig and color by genes and orthogroups and add edge-coverage to db
echo "building vizitig graph..."
$VIZITIG build $name/graphs/dbg_g.fa -n ${name}
$VIZITIG index build ${name} -t RustIndex


echo "adding edge-coverage to vizitig DB..."
python3 scripts/add_edge_coverage_to_db.py \
        ${name}/graphs/dbg_g.gfa\
        $DB


echo "coloring vizitig graph by genes..."
for file in "$name"/genes/*.fa; do
    NAME=$(basename "$file" .fa)
    "$VIZITIG" color -f "$file" -m "g_${NAME}" "${name}"
done

echo "coloring vizitig graph by orthogroups..."
for file in "$name"/ogs/*.fa; do
    NAME=$(basename "$file" .fa)
    "$VIZITIG" color -f "$file" -m "o_${NAME}" "${name}"
done

