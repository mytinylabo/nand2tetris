#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
require_relative 'modules/jack_tokenizer'
require_relative 'modules/jack_compilation_engine'

src_path = Pathname(ARGV[0])
src_dst_pairs = []
if src_path.file?
  src_dst_pairs.push([src_path, src_path.sub_ext('.vm')])

elsif src_path.directory?
  src_path.glob('*.jack').each do |src|
    src_dst_pairs.push([src, src_path + src.split.last.sub_ext('.vm')])
  end

else
  raise "invalid input path: #{src_path}"
end

src_dst_pairs.each do |pair|
  src, dst = pair
  tokens = JackTokenizer.new(src.read).to_enum

  dst.open(mode='w') do |f|
    compiler = JackCompilationEngine.new(tokens, vm_out: f)
    compiler.compile_class
  end
end
