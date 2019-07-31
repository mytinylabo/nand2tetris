#!/bin/bash

echo 'Testing VM translator modules...'
ruby ./hvm/modules/hvm_syntax.rb
ruby ./hvm/modules/hvm_parser.rb
ruby ./hvm/modules/hvm_code_writer.rb

echo 'Testing VM translator...'

list=(
    ./StackArithmetic/SimpleAdd/SimpleAdd
    ./StackArithmetic/StackTest/StackTest
    ./MemoryAccess/BasicTest/BasicTest
    ./MemoryAccess/PointerTest/PointerTest
    ./MemoryAccess/StaticTest/StaticTest
)

for src in ${list[@]}
do
    echo ${src}
    rm -f ${src}.asm
    rm -f ${src}.out
    ./hvm/hvm.rb ${src}.vm
    ../../tools/CPUEmulator.sh ${src}.tst
done
