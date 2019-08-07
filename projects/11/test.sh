#!/bin/bash

set -eu

echo 'Testing Jack compiler modules...'
ruby ./jack/modules/jack_tokenizer.rb
ruby ./jack/modules/jack_compilation_engine.rb

echo 'Testing tokenization...'
tmp_path="/tmp/jack_tokens_$$.xml"

list=(
    ../10/ExpressionLessSquare/Main
    ../10/ExpressionLessSquare/Square
    ../10/ExpressionLessSquare/SquareGame
    ../10/Square/Main
    ../10/Square/Square
    ../10/Square/SquareGame
    ../10/ArrayTest/Main
)

for src in ${list[@]}
do
    echo $src
    ruby ./token_to_xml.rb ${src}.jack >$tmp_path
    ../../tools/TextComparer.sh ${src}T.xml $tmp_path
    rm $tmp_path
done

echo 'Testing compilation...'
tmp_path="/tmp/jack_syntax_tree_$$.xml"

list=(
    ../10/ExpressionLessSquare/Main
    ../10/ExpressionLessSquare/Square
    ../10/ExpressionLessSquare/SquareGame
    ../10/Square/Main
    ../10/Square/Square
    ../10/Square/SquareGame
    ../10/ArrayTest/Main
)

for src in ${list[@]}
do
    echo $src
    ruby ./parse_tree_to_xml.rb ${src}.jack >$tmp_path
    ../../tools/TextComparer.sh ${src}.xml $tmp_path
    rm $tmp_path
done
