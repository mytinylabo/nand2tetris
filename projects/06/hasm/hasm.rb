#!/usr/bin/env ruby

require 'pathname'
require_relative 'hasm_modules'

src_path = ARGV[0]
dst_path = Pathname(src_path).sub_ext('.hack').to_s
raw_src = File.read(src_path)

parser = HasmParser.new(raw_src)
symbol_table = HasmSymbolTable.new

# 1st pass: collect labels
while parser.has_more_commands?
  parser.advance
  case parser.command_type
  when :L_COMMAND
    if symbol_table.contains?(parser.symbol)
      parser.put_current_line
      raise 'symbol already defined'
    end
    symbol_table.add_entry(parser.symbol, parser.address)
  end
end

parser = HasmParser.new(raw_src)
next_var_addr = 0x0010

File.open(dst_path, mode='w') do |outfile|
  # 2nd pass: parse commands
  while parser.has_more_commands?
    parser.advance
    case parser.command_type
    when :A_COMMAND
      code = 0
      if parser.symbol =~ /^-?[0-9]+$/
        # Number
        code = parser.symbol.to_i
        # Convert negative number to its complement
        code = (1<<16) - code if code < 0
      elsif symbol_table.contains?(parser.symbol)
        # Existing symbol
        code = symbol_table.get_address(parser.symbol)
      else
        # New symbol
        symbol_table.add_entry(parser.symbol, next_var_addr)
        code = next_var_addr # Assign an unused address
        next_var_addr += 1
      end

      # Code follows A operation marker '0'
      code_str = format('0%.15b', code)
      if code_str.length > 16
        # Not allow to load a value of >=16 bits length
        parser.put_current_line
        raise 'value out of range'
      end

      outfile.puts code_str
    when :L_COMMAND
      # Nothing to do

    when :C_COMMAND
      dest = HasmCode.dest(parser.dest)

      comp = HasmCode.comp(parser.comp)
      if comp.nil?
        parser.put_current_line
        raise 'invalid expression'
      end

      jump = HasmCode.jump(parser.jump)
      if jump.nil?
        parser.put_current_line
        raise 'invalid jump condition'
      end

      code = 0
      code |= dest<<3
      code |= comp<<6
      code |= jump

      # Code follows C operation marker '111'
      outfile.puts format('111%.13b', code)
    end
  end
end
