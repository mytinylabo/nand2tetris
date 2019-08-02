#!/bin/bash

set -eu

echo 'Testing Jack compiler modules...'
ruby ./jack/modules/jack_tokenizer.rb

echo 'Testing tokenization...'
tmp_path="/tmp/jack_tokens_$$.xml"

list=(
    ExpressionLessSquare/Main
    ExpressionLessSquare/Square
    ExpressionLessSquare/SquareGame
    Square/Main
    Square/Square
    Square/SquareGame
    ArrayTest/Main
)

for src in ${list[@]}
do
    echo $src
    ruby ./token_to_xml.rb ${src}.jack >$tmp_path
    ../../tools/TextComparer.sh ${src}T.xml $tmp_path
    rm $tmp_path
done
