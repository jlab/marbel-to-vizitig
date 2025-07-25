conda activate marbel
source /mnt/data/bin/vizitig/venv/bin/activate

# project name
name=$1

# parameters
# marbel
N_SPECIES=10
N_OGS=2000
LIB_SIZE=100000
N_SAMPLES="3 3"
SEED=23

# dbg
K=20 
MEM=10 # memory limit 


# make directories
mkdir $name
cd $name
mkdir samples graphs simulated_reads
cd ..


# marbel
echo "generating marbel dataset..."
marbel --n-species $N_SPECIES \
        --n-orthogroups $N_OGS \
        --library-size $LIB_SIZE \
        --n-samples $N_SAMPLES \
        --seed $SEED \
        --outdir $name/simulated_reads \
        --library-size-distribution negative_binomial \
        --threads 26 \
        --group-orthology-level very_high \
        --error-model NextSeq


# make csv
/mnt/data/bin/marbel-to-vizitig/3_make_list.sh $name


# dbg
PATH="/mnt/data/bin/dbg/target/release/:$PATH" # add dbg to path

echo "building debruijn graph with dbg..."
dbg --csv $name/file_list.csv \
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
dbg --cached-graph $name/graphs/dbg_g.graph.dbg \
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
    --color_by IDs "mapped IDs" \

python scripts/gfa2vizitig.py \
	$name/graphs/dbg_o.gfa \
	$name/graphs/dbg_o.fa \
	--sample_dir $name/ogs \
    --color_by IDs "mapped IDs" \


# add graph to vizitig and color by genes and orthogroups
echo "building vizitig graph..."
vizitig build $name/graphs/dbg_g.fa -n $name
vizitig index build $name -t RustIndex

echo "coloring vizitig graph by genes..."
files=$(ls $name/genes/)
for file in $files
do
    NAME=$(echo $file | sed "s;.fa;;g")
    vizitig color -f $name/genes/$file -m g_$NAME $name
done

echo "coloring vizitig graph by orthogroups..."
files=$(ls $name/ogs/)
for file in $files
do
    NAME=$(echo $file | sed "s;.fa;;g")
    vizitig color -f $name/ogs/$file -m o_$NAME $name
done
