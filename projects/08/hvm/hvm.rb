#!/usr/bin/env ruby

require 'pathname'
require_relative 'modules/hvm_parser'
require_relative 'modules/hvm_code_writer'

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

  # TODO: Make adding comments optional
  writer.write_comment("#{File.basename(src_path)} #{parser.current_line}")

  case parser.command_type
  when :C_ARITHMETIC
    writer.write_arithmetic(parser.arg1)

  when :C_PUSH, :C_POP
    writer.write_push_pop(parser.command_type, parser.arg1, parser.arg2)

  when :C_LABEL
    writer.write_label(parser.arg1)

  when :C_GOTO
    writer.write_goto(parser.arg1)

  when :C_IF
    writer.write_if(parser.arg1)

  when :C_FUNCTION
    writer.write_function(parser.arg1, parser.arg2)

  when :C_CALL
    writer.write_call(parser.arg1, parser.arg2)

  when :C_RETURN
    writer.write_return

  else
    $stderr.puts parser.current_line
    raise 'syntax error'
  end
end

writer.close
