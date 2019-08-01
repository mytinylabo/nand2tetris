#!/bin/bash

set -eu

# Write source VM code as comment to .asm?
[ $# = 1 ] && [ " $1" = " -c" ] && comment="-c" || comment=""

echo 'Testing VM translator modules...'
ruby ./hvm/modules/hvm_syntax.rb
ruby ./hvm/modules/hvm_parser.rb
ruby ./hvm/modules/hvm_code_writer.rb

echo 'Testing VM translator...'

# Target VM code is a file
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
    ./hvm/hvm.rb -p ${comment} ${src}.vm
    ../../tools/CPUEmulator.sh ${src}.tst
done

# Target VM code is a directory
list=(
    ./FunctionCalls/StaticsTest
    ./FunctionCalls/NestedCall
    ./FunctionCalls/FibonacciElement
)

for dir in ${list[@]}
do
    echo ${dir}
    src=`echo ${dir} | awk -F '/' '{ print $NF }'`
    rm -f ${dir}/${src}.asm
    rm -f ${dir}/${src}.out
    ./hvm/hvm.rb ${comment} ${dir}
    ../../tools/CPUEmulator.sh ${dir}/${src}.tst
done
