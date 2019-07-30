#!/usr/bin/env ruby

require 'pathname'
require_relative 'modules/hvm_parser.rb'
require_relative 'modules/hvm_code_writer.rb'

# TODO: Accept a directory(multiple .vm files)
src_path = ARGV[0]
dst_path = Pathname(src_path).sub_ext('.asm').to_s
raw_src = File.read(src_path)

parser = HvmParser.new(raw_src)
writer = HvmCodeWriter.new(File.open(dst_path, mode='w'))
writer.set_filename(File.basename(src_path, '.vm'))

# Translates a vm file into the target asm file
while parser.has_more_commands?
  parser.advance
  case parser.command_typea
  when :C_ARITHMETIC
    writer.write_arithmetic(parser.arg1)

  when :C_PUSH, :C_POP
    writer.write_push_pop(parser.command_type, parser.arg1, parser.arg2)

  else
    $stderr.puts parser.current_line
    raise 'syntax error'
  end
end

writer.close
