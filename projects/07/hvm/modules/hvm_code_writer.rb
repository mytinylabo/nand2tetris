
class HvmCodeWriter
  def initialize(output)
    @output = output
    @filename = ''
    @indices = Hash.new(-1)
  end

  def set_filename(filename)
    @filename = filename
    @indices[:static] = -1
  end

  def close
    @output.close
  end

  def write_arithmetic(operator)
    asm = case operator.to_sym
    when :neg then asm_neg
    when :not then asm_not
    when :add then asm_add
    when :sub then asm_sub
    when :and then asm_and
    when :or  then asm_or
    when :eq
      @indices[:eq] += 1
      asm_eq(@indices[:eq])
    when :gt
      @indices[:gt] += 1
      asm_gt(@indices[:gt])
    when :lt
      @indices[:lt] += 1
      asm_lt(@indices[:lt])
    else
      raise "invalid operator: #{operator}"
    end

    @output.puts(asm)
  end

  def write_push_pop(command_type, segment, index)
    asm = case command_type
    when :C_PUSH
      case segment.to_sym
      when :constant
        asm_push_constant(index)
      else
        raise "invalid segment: #{segment}"
      end

    when :C_POP
    else
      raise "invalid command_type: #{command_type.to_s}"
    end

    asm ||= ''
    @output.puts(asm)
  end

  private
  def asm_push_constant(index)
    <<~asm.strip
    @#{index}
    D=A
    @SP
    AM=M+1
    A=A-1
    M=D
    asm
  end

  def asm_neg
    <<~asm.strip
    @SP
    A=M-1
    M=-M
    asm
  end

  def asm_not
    <<~asm.strip
    @SP
    A=M-1
    M=!M
    asm
  end

  def calc_base(expression)
    <<~asm.strip
    @SP
    AM=M-1
    D=M
    A=A-1
    #{expression}
    asm
  end

  def asm_add
    calc_base('M=D+M')
  end

  def asm_sub
    calc_base('M=M-D')
  end

  def asm_and
    calc_base('M=D&M')
  end

  def asm_or
    calc_base('M=D|M')
  end

  def comp_base(operator, index)
    <<~asm.strip
    @SP
    AM=M-1
    D=M
    A=A-1
    D=M-D
    M=-1
    @END_#{operator}_#{index}
    D;J#{operator}
    @SP
    A=M-1
    M=0
    (END_#{operator}_#{index})
    asm
  end

  def asm_eq(index)
    comp_base('EQ', index)
  end

  def asm_gt(index)
    comp_base('GT', index)
  end

  def asm_lt(index)
    comp_base('LT', index)
  end
end

return if $0 != __FILE__

require 'tempfile'
require 'test/unit'
include Test::Unit::Assertions

probe = Tempfile.open
writer = HvmCodeWriter.new(probe)
writer.set_filename('Test')

%w[neg not add sub and or eq gt lt].each do |operator|
  writer.write_arithmetic(operator)
end

writer.write_push_pop(:C_PUSH, 'constant', 0)

probe.rewind
# Just check there's no blank line
assert probe.readlines.none?{ |line| line.chomp.empty? }

assert !probe.closed?
writer.close
assert probe.closed?
