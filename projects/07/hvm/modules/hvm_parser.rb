require_relative 'hvm_syntax'

class HvmParser
  Token = {
    segment: /(?:argument|local|static|constant|this|that|pointer|temp)/,
    index:   /[0-9]+/
  }

  Syntax = [
    HvmSyntax.new(/push (#{Token[:segment]}) (#{Token[:index]})/, :C_PUSH),
    HvmSyntax.new(/pop (#{Token[:segment]}) (#{Token[:index]})/,  :C_POP),
    HvmSyntax.new(/add/, :C_ARITHMETIC),
    HvmSyntax.new(/sub/, :C_ARITHMETIC),
    HvmSyntax.new(/neg/, :C_ARITHMETIC),
    HvmSyntax.new(/eq/,  :C_ARITHMETIC),
    HvmSyntax.new(/gt/,  :C_ARITHMETIC),
    HvmSyntax.new(/lt/,  :C_ARITHMETIC),
    HvmSyntax.new(/and/, :C_ARITHMETIC),
    HvmSyntax.new(/or/,  :C_ARITHMETIC),
    HvmSyntax.new(/not/, :C_ARITHMETIC)
  ]

  def initialize(raw_src)
    @src_lines = raw_src.each_line.with_index

    @line = ''
    @index = 0

    clear_command
  end
  attr_reader :command_type

  def has_more_commands?
    # Seek next command skipping comment and blank lines
    loop do
      line, i = peek_next_line
      return false if line.nil? # End of input

      stripped_line = strip(line)
      if stripped_line.empty?
        next_line
      else
        break
      end
    end
    true
  end

  def advance
    @line, index = next_line
    @index = index + 1 # 1-based indexing
    stripped_line = strip(@line)

    command = Syntax.find{ |s| s.applies_to?(stripped_line) }
    if command
      @command_type = command.type
      @args = command.parse_args(stripped_line)
    else
      # Syntax error
    end
  end

  def arg1
    @args[:arg1]
  end

  def arg2
    @args[:arg2].to_i
  end

  def current_line
    "line:#{@index}| #{@line.chomp}"
  end

  private
  def clear_command
    @command_type = nil
    @args = {}
  end

  def peek_next_line
    begin
      @src_lines.peek
    rescue StopIteration
      nil
    end
  end

  def next_line
    begin
      @src_lines.next
    rescue StopIteration
      nil
    end
  end

  def strip(line)
    line.gsub(%r!//.*$!, '') # Delete comment
        .gsub(/ +/, ' ')     # Reduce trailing spaces
        .strip               # Trim spaces on head and tail
  end
end

return if $0 != __FILE__

require 'test/unit'
include Test::Unit::Assertions

# Test no commands
src =<<EOS
// This source file consists of
    // comments

// and blank // lines
//

EOS

parser = HvmParser.new(src)
assert !parser.has_more_commands?
assert_equal parser.current_line, 'line:0| '

# Test stack & arithmetic commands
src =<<EOS
push argument 0
  push constant 5 // comment
sub
pop  local  0
EOS

parser = HvmParser.new(src)
types = []
arg1s = []
while parser.has_more_commands?
  parser.advance
  types.push(parser.command_type)
  arg1s.push(parser.arg1)
end
assert_equal types, [:C_PUSH, :C_PUSH, :C_ARITHMETIC, :C_POP]
assert_equal arg1s, ['argument', 'constant', 'sub', 'local']
assert_equal parser.current_line, 'line:4| pop  local  0'
