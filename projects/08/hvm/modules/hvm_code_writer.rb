
class HvmCodeWriter
  def initialize(output)
    @output = output
    @filename = ''
    @indices = Hash.new(-1)
  end

  def set_filename(filename)
    @filename = filename
  end

  def close
    @output.close
  end

  def write_comment(string)
    @output.puts("// #{string}")
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
      when :constant then asm_push_constant(index)
      when :static   then asm_push_static(index)
      when :local    then asm_push_local(index)
      when :argument then asm_push_argument(index)
      when :this     then asm_push_this(index)
      when :that     then asm_push_that(index)
      when :pointer  then asm_push_pointer(index)
      when :temp     then asm_push_temp(index)
      else
        raise "invalid segment: #{segment}"
      end

    when :C_POP
      case segment.to_sym
      when :static   then asm_pop_static(index)
      when :local    then asm_pop_local(index)
      when :argument then asm_pop_argument(index)
      when :this     then asm_pop_this(index)
      when :that     then asm_pop_that(index)
      when :pointer  then asm_pop_pointer(index)
      when :temp     then asm_pop_temp(index)
      else
        raise "invalid segment: #{segment}"
      end

    else
      raise "invalid command_type: #{command_type}"
    end

    @output.puts(asm)
  end

  def write_label(label)
    @output.puts(asm_label(label))
  end

  def write_goto(label)
    @output.puts(asm_goto(label))
  end

  def write_if(label)
    @output.puts(asm_if(label))
  end

  private
  def push_d
    <<~asm.strip
    @SP
    AM=M+1
    A=A-1
    M=D
    asm
  end

  def push_direct(address)
    <<~asm.strip
    @#{address}
    D=M
    #{push_d}
    asm
  end

  def push_indirect_offset_le_2(segment, index)
    <<~asm.strip
    @#{segment}
    #{['A=M', 'A=M+1', %w[A=M+1 A=A+1].join("\n")][index]}
    D=M
    asm
  end

  def push_indirect_offset_ge_3(segment, index)
    <<~asm.strip
    @#{segment}
    D=M
    @#{index}
    A=D+A
    D=M
    asm
  end

  def push_indirect(segment, index)
    <<~asm.strip
    #{index <= 2 ? push_indirect_offset_le_2(segment, index) : push_indirect_offset_ge_3(segment, index)}
    #{push_d}
    asm
  end

  def asm_push_constant(immediate)
    <<~asm.strip
    @#{immediate}
    D=A
    #{push_d}
    asm
  end

  def asm_push_static(index)
    push_direct("#{@filename}.#{index}")
  end

  def asm_push_local(index)
    push_indirect('LCL', index)
  end

  def asm_push_argument(index)
    push_indirect('ARG', index)
  end

  def asm_push_this(index)
    push_indirect('THIS', index)
  end

  def asm_push_that(index)
    push_indirect('THAT', index)
  end

  def asm_push_pointer(index)
    push_direct(3 + index)
  end

  def asm_push_temp(index)
    push_direct(5 + index)
  end

  def pop_to_d
    <<~asm.strip
    @SP
    AM=M-1
    D=M
    asm
  end

  def pop_direct(address)
    <<~asm.strip
    #{pop_to_d}
    @#{address}
    M=D
    asm
  end

  def pop_indirect_le_6(segment, index)
    offset = [index == 0 ? 'A=M' : 'A=M+1'] + (index - 1).times.map{ 'A=A+1' }
    <<~asm.strip
    #{pop_to_d}
    @#{segment}
    #{offset.join("\n")}
    M=D
    asm
  end

  def pop_indirect_ge_7(segment, index)
    <<~asm.strip
    @#{segment}
    D=M
    @#{index}
    D=D+A
    @R13
    M=D
    #{pop_to_d}
    @R13
    A=M
    M=D
    asm
  end

  def pop_indirect(segment, index)
    index <= 6 ? pop_indirect_le_6(segment, index)
               : pop_indirect_ge_7(segment, index)
  end

  def asm_pop_static(index)
    pop_direct("#{@filename}.#{index}")
  end

  def asm_pop_local(index)
    pop_indirect('LCL', index)
  end

  def asm_pop_argument(index)
    pop_indirect('ARG', index)
  end

  def asm_pop_this(index)
    pop_indirect('THIS', index)
  end

  def asm_pop_that(index)
    pop_indirect('THAT', index)
  end

  def asm_pop_pointer(index)
    pop_direct(3 + index)
  end

  def asm_pop_temp(index)
    pop_direct(5 + index)
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

  def calc(expression)
    <<~asm.strip
    @SP
    AM=M-1
    D=M
    A=A-1
    #{expression}
    asm
  end

  def asm_add
    calc('M=D+M')
  end

  def asm_sub
    calc('M=M-D')
  end

  def asm_and
    calc('M=D&M')
  end

  def asm_or
    calc('M=D|M')
  end

  def comp(operator, index)
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
    comp('EQ', index)
  end

  def asm_gt(index)
    comp('GT', index)
  end

  def asm_lt(index)
    comp('LT', index)
  end

  def asm_label(label)
    "(#{label})"
  end

  def asm_goto(label)
    <<~asm.strip
    @#{label}
    0;JMP
    asm
  end

  def asm_if(label)
    <<~asm.strip
    @SP
    AM=M-1
    D=M
    @#{label}
    D;JNE
    asm
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

%w[constant static local argument this that pointer temp].each_with_index do |segment, index|
  writer.write_push_pop(:C_PUSH, segment, index)
end

%w[static local argument this that pointer temp].each_with_index do |segment, index|
  writer.write_push_pop(:C_POP, segment, index)
end

writer.write_label('foo')
writer.write_goto('bar')
writer.write_if('baz')

probe.rewind
# Just check there's no blank line
assert probe.readlines.none?{ |line| line.chomp.empty? }

assert !probe.closed?
writer.close
assert probe.closed?
