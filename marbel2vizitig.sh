conda activate marbel
source /mnt/data/bin/vizitig/venv/bin/activate

# project name
name=$1

mkdir $name
cd $name
mkdir samples GA_transcripts graphs file_list_csv simulated_reads
cd ..

# marbel
N_OGS=2000

marbel --n-species 10 \
        --n-orthogroups $N_OGS \
        --library-size 100000 \
        --n-samples 3 3 \
        --seed 23 \
        --outdir $name/simulated_reads

# make csv

/mnt/data/bin/marbel-to-vizitig/3_make_list.sh $name

# dbg

# path to dbg
PATH="/mnt/data/bin/dbg/target/release/:$PATH"

dbg --csv $name/file_list_csv/file_list.csv \
    --memory 10 \
    --out $name/graphs/dbg_graph \
    --format gfa \
    --summarizer id \
    --gene-summary $name/simulated_reads/summary/gene_summary.csv \
    --gene-to-og # label by orthogroups instead of gene names

# graph aligner

GraphAligner \
    -g $name/graphs/dbg_graph.gfa \
    -f $name/simulated_reads/summary/metatranscriptome_reference.fasta \
    -a $name/graphs/dbg_graph_aligned.gaf' \
    -x dbg


# gfa to vizitig

python scripts/gfa2vizitig.py \
	$name/graphs/dbg_graph.gfa \
	$name/graphs/dbg_graph.fa \
	3 \
	--sample_dir $name/samples \
	$name/GA_transcripts/generated_transcripts.fa \
	$name/graphs/dbg_graph_aligned.gaf'


# add to vizitig

vizitig build $name/graphs/dbg_graph.fa -n $name

vizitig index build $name -t RustIndex

vizitig annotate $name --transcripts $name/simulated_reads/summary/metratranscriptome_reference.fasta
vizitig annotate $name -e $name/GA_transcripts/generated_transcripts.fa

for og in &(seq 0 $N_OGS)
do
	file=$name/samples/Sample_$og.fa
	if [ -f $file ]
	then
		vizitig color -f $file -m og$og $name
	fi
done
