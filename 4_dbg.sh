#!/bin/bash

#SBATCH --job-name=dbg               # Job name
#SBATCH --partition=bcf                # Partition name
#SBATCH --ntasks=1                      # Run on a single task
#SBATCH --cpus-per-task=4             # Number of CPU cores per task
#SBATCH --mem=4gb                     # Total memory limit
#SBATCH --time=1-00:00:00           

# replace with your path to dbg
PATH="/mnt/data/bin/dbg/target/release:$PATH"

main_folder=$1

# go into folder with reads to execute
cd $main_folder/simulated_reads/

# -r should be half of the job memory request
dbg --csv ../file_list_csv/file_list.csv \
    --memory 2 \
    --out ../graphs/$main_folder'.gfa' \
    --format gfa \

cd ../..
