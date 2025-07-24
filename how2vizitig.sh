#!/bin/bash

cd ~/vizitig
source venv/bin/activate

vizitig build ./bigger_test.fa -n bigger_test
vizitig index build bigger_test -t RustIndex # or SQLite

vizitig annotate bigger_test --transcripts metatranscriptome_reference.fasta
vizitig annotate bigger_test -e generated_transcipts.fa

vizitig color -f ./my_test_samples/Sample_A_1.fa -m sampleA1 bigger_test
vizitig color -f ./my_test_samples/Sample_A_2.fa -m sampleA2 bigger_test
vizitig color -f ./my_test_samples/Sample_A_3.fa -m sampleA3 bigger_test
vizitig color -f ./my_test_samples/Sample_B_1.fa -m sampleB1 bigger_test
vizitig color -f ./my_test_samples/Sample_B_2.fa -m sampleB2 bigger_test
vizitig color -f ./my_test_samples/Sample_B_3.fa -m sampleB3 bigger_test
