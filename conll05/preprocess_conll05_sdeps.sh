#!/bin/bash

# You'll want to change this
STANFORD=/iesl/canvas/strubell/stanford-parser-full-2017-06-09

STANFORD_CP="$STANFORD/*:"

input_file=$1

# First, convert the constituencies from the ontonotes files to the format expected
# by the converter
echo "Extracting trees from: $input_file"
# word pos parse -> stick words, pos into parse as terminals
zcat $input_file | \
awk '{gsub(/\(/, "-RRB-", $1); gsub(/\)/, "-LRB-", $1); gsub(/\(/, "-RRB-", $2); gsub(/\)/, "-LRB-", $2); gsub(/#/, "$", $1); gsub(/#/, "$", $2); print $2" "$1"\t"$3}' | \
sed 's/\(.*\)\t\(.*\)\*\(.*\)/\2(\1)\3/' > "$input_file.parse"

# Now convert those parses to dependencies
# Output will have the extension .dep
echo "Converting to dependencies: $input_file.parse"
java -mx150m -cp $STANFORD_CP edu.stanford.nlp.trees.EnglishGrammaticalStructure \
    -treeFile "$input_file.parse" -basic -conllx -keepPunct -makeCopulaHead > "$input_file.parse.sdeps"
#java -cp $CLASSPATH edu.emory.clir.clearnlp.bin.C2DConvert \
#    -h $headrules \
#    -i "$input_file.parse" \
#    -pe parse

# Now assign auto part-of-speech tags
# Output will have extension .cnlp
#echo "POS tagging: $input_file.parse.sdeps"
#java -cp $CLASSPATH edu.emory.clir.clearnlp.bin.NLPDecode \
#    -mode pos \
#    -c config_decode_pos.xml \
#    -i "$input_file.parse.sdeps" \
#    -ie dep
#
## Finally, paste the original file together with the dependency parses and auto pos tags
#f_converted="$input_file.parse.sdeps"
#f_pos="$input_file.parse.sdeps.cnlp"
#f_combined="$f_converted.sdeps.combined"
#paste <(zcat $input_file | awk '{if(NF == 0){print ""} else {print "_\t_\t_\t"$1"\t"$2}}' ) \
#    <(awk '{print $2}' $f_pos) \
#    <(awk '{print $6"\t"$7"\t"$9}' $f_converted) \
#    <(zcat $input_file | awk '{if(NF == 0){print ""} else {print $5"\t"$6"\t-\t-\t"$4}}' ) \
#    <(zcat $input_file | awk '{if(NF == 0){print ""} else {print $0"\t_"}}' | tr -s ' ' | cut -d' ' -f7- | sed 's/ /\t/g') \
#> $f_combined
