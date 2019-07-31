#!/usr/bin/env ruby

require 'pathname'
require_relative 'modules/hvm_parser'
require_relative 'modules/hvm_code_writer'

src_path = Pathname(ARGV[0])
src_list = []
dst_path = ''
if src_path.file?
  src_list = [src_path]
  dst_path = src_path.sub_ext('.asm')

elsif src_path.directory?
  src_list = src_path.glob('*.vm')
  dst_path = src_path + src_path.split.last.sub_ext('.asm')

else
  raise "invalid input path: #{src_path}"
end

writer = HvmCodeWriter.new(File.open(dst_path, mode='w'))

src_list.each do |src_file|
  parser = HvmParser.new(src_file.read)
  writer.set_filename(src_file.basename('.vm'))

  # Translates a vm file into the target asm file
  while parser.has_more_commands?
    parser.advance

    # TODO: Make adding comments optional
    writer.write_comment("#{src_file.basename} #{parser.current_line}")

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
end

writer.close
