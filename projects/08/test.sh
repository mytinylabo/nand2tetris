#!/bin/bash

set -eu

echo 'Testing VM translator modules...'
ruby ./hvm/modules/hvm_syntax.rb
ruby ./hvm/modules/hvm_parser.rb
ruby ./hvm/modules/hvm_code_writer.rb

echo 'Testing VM translator...'

list=(
    ../07/StackArithmetic/SimpleAdd/SimpleAdd
    ../07/StackArithmetic/StackTest/StackTest
    ../07/MemoryAccess/BasicTest/BasicTest
    ../07/MemoryAccess/PointerTest/PointerTest
    ../07/MemoryAccess/StaticTest/StaticTest
    ./ProgramFlow/BasicLoop/BasicLoop
    ./ProgramFlow/FibonacciSeries/FibonacciSeries
    ./FunctionCalls/SimpleFunction/SimpleFunction
)

for src in ${list[@]}
do
    echo ${src}
    rm -f ${src}.asm
    rm -f ${src}.out
    ./hvm/hvm.rb ${src}.vm
    ../../tools/CPUEmulator.sh ${src}.tst
done
