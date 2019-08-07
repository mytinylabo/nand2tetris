
class JackVmWriter
  def initialize(output)
    @output = output
  end

  def write_push(segment, index)
    @output.puts "push #{seg(segment)} #{index}"
  end

  def write_pop(segment, index)
    @output.puts "pop #{seg(segment)} #{index}"
  end

  def write_arithmetic(command)
    @output.puts op(command)
  end

  def write_label(label)
    @output.puts "label #{label}"
  end

  def write_goto(label)
    @output.puts "goto #{label}"
  end

  def write_if(label)
    @output.puts "if-goto #{label}"
  end

  def write_call(name, n_args)
    @output.puts "call #{name} #{n_args}"
  end

  def write_function(name, n_locals)
    @output.puts "function #{name} #{n_locals}"
  end

  def write_return
    @output.puts "return"
  end

  private
  def seg(segment)
    case segment
    when :CONST   then 'constant'
    when :ARG     then 'argument'
    when :LOCAL   then 'local'
    when :STATIC  then 'static'
    when :THIS    then 'this'
    when :THAT    then 'that'
    when :POINTER then 'pointer'
    when :TEMP    then 'temp'
    end
  end

  def op(command)
    case command
    when :ADD then 'add'
    when :SUB then 'sub'
    when :NEG then 'neg'
    when :EQ  then 'eq'
    when :GT  then 'gt'
    when :LT  then 'lt'
    when :AND then 'and'
    when :OR  then 'or'
    when :NOT then 'not'
    end
  end
end

return if $0 != __FILE__

require 'tempfile'
require 'test/unit'
include Test::Unit::Assertions

probe = Tempfile.open
writer = JackVmWriter.new(probe)

[:CONST, :ARG, :LOCAL, :STATIC, :THIS, :THAT, :POINTER, :TEMP].each_with_index do |segment, i|
  writer.write_push(segment, i)
end

writer.write_pop(:CONST, 100)

[:ADD ,:SUB ,:NEG ,:EQ ,:GT ,:LT ,:AND ,:OR ,:NOT].each do |command|
  writer.write_arithmetic(command)
end

writer.write_label('foo')
writer.write_goto('bar')
writer.write_if('baz')

writer.write_call('foo', 2)
writer.write_function('bar', 4)
writer.write_return

expected =<<EOS
push constant 0
push argument 1
push local 2
push static 3
push this 4
push that 5
push pointer 6
push temp 7
pop constant 100
add
sub
neg
eq
gt
lt
and
or
not
label foo
goto bar
if-goto baz
call foo 2
function bar 4
return
EOS

probe.rewind
assert_equal expected, probe.read

probe.close
