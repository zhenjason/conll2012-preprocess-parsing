#!/bin/bash

# You'll want to change this if you're not running from the project's root directory
#CLEARNLP=`pwd`
#CLEARLIB=$CLEARNLP/lib
#CLASSPATH=$CLEARLIB/clearnlp-3.1.2.jar:$CLEARLIB/args4j-2.0.29.jar:$CLEARLIB/log4j-1.2.17.jar:$CLEARLIB/hppc-0.6.1.jar:$CLEARLIB/xz-1.5.jar:$CLEARLIB/clearnlp-dictionary-3.2.jar:$CLEARLIB/clearnlp-general-en-pos-3.2.jar:$CLEARLIB/clearnlp-global-lexica-3.1.jar:.
#
#input_dir=$1
#headrules=$CLEARNLP/headrule_en_stanford.txt
#pos_config=$CLEARNLP/config_decode_pos.xml


STANFORD_CP="$STANFORD_PARSER/*:$STANFORD_POS/*:"
postagger_model="$STANFORD_POS/models/english-left3words-distsim.tagger"

input_dir=$1

# First, convert the constituencies from the ontonotes files to the format expected
# by the converter
for f in `find $input_dir -type f -not -path '*/\.*' -name "*_conll"`; do
    echo "Extracting trees from: $f"
    # word pos parse -> stick words, pos into parse as terminals
    awk '{if (substr($1,1,1) !~ /#/ ) print $5" "$4"\t"$6}' $f | \
    sed 's/\/\([.?-]\)/\1/' | \
    sed 's/\(.*\)\t\(.*\)\*\(.*\)/\2(\1)\3/' > "$f.parse"
#    awk '{if(NF && substr($1,1,1) !~ /\(/){print "(TOP(INTJ(UH XX)))"} else {print}}' > "$f.parse"
done

# Now convert those parses to dependencies
# Output will have the extension .dep
for f in `find $input_dir/* -type f -not -path '*/\.*' -name "*_conll"`; do
    echo "Converting to dependencies: $f"
    java -Xmx8g -cp $STANFORD_CP edu.stanford.nlp.trees.EnglishGrammaticalStructure \
    -treeFile "$f.parse" -basic -conllx -keepPunct -makeCopulaHead > "$f.parse.sdeps"
done

# Now assign auto part-of-speech tags
# Output will have extension .cnlp
for f in `find $input_dir/* -type f -not -path '*/\.*' -name "*_conll"`; do
    echo "POS tagging: $f"
    awk '{if(NF){printf "%s ", $2} else{ print "" }}' "$f.parse.sdeps" > "$f.parse.sdeps.posonly"

    java -Xmx8g -cp $STANFORD_CP edu.stanford.nlp.tagger.maxent.MaxentTagger \
        -model $postagger_model \
        -textFile "$f.parse.sdeps.posonly" \
        -tokenize false \
        -outputFormat tsv \
        -sentenceDelimiter newline \
        > "$f.parse.sdeps.pos"
done

# Finally, paste the original file together with the dependency parses and auto pos tags
for f in `find $input_dir -type f -not -path '*/\.*' -name "*_conll"`; do
    f_converted="$f.parse.sdeps"
    f_pos="$f.parse.sdeps.pos"
    f_combined="$f_converted.combined"
    paste <(awk '{if (substr($1,1,1) !~ /#/ ) {print $1"\t"$2"\t"$3"\t"$4"\t"$5}}' $f) \
        <(awk '{print $2}' $f_pos) \
        <(awk '{if(NF == 0){print ""} else {print $7"\t"$8"\t_"}}' $f_converted) \
        <(awk '{if (substr($1,1,1) !~ /#/ ) {print $0}}' $f | tr -s ' ' | cut -d' ' -f7- | sed 's/ /\t/g') \
    > $f_combined
done
