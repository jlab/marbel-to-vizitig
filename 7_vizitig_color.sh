# $1: sample dir
# $2: category (gene/og)
# $3: vizitig graph name

files=$(ls $1)
for file in $files
do
    NAME=$(echo $file | sed "s;.fa;;g")
    vizitig color -f $1/$file -m $2-$NAME $3
done