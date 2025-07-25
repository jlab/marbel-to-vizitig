#!/bin/bash

#SBATCH --job-name=aligning               # Job name
#SBATCH --partition=bcf                # Partition name
#SBATCH --ntasks=1                      # Run on a single task
#SBATCH --cpus-per-task=2             # Number of CPU cores per task
#SBATCH --mem=2gb                     # Total memory limit
#SBATCH --time=1-00:00:00

# replace with your path to GraphAligner
path_to_GA=$HOME/miniconda3/bin

main_folder=$1

GraphAligner \
    -g $main_folder/graphs/$main_folder'.gfa' \
    -f $main_folder/simulated_reads/summary/metatranscriptome_reference.fasta \
    -a $main_folder/graphs/$main_folder'_aligned.gaf' \
    -x dbg
