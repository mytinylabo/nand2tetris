
class HvmSyntax
  def initialize(pattern, type)
    @pattern = /^#{pattern}$/
    @type = type
  end
  attr_reader :type

  def applies_to?(line)
    @pattern =~ line
  end

  # Expected to be called with a string which passes applies_to? check
  def parse_args(line)
    match = @pattern.match(line)
    return {} if match.nil?

    args = match.to_a.drop(1)

    # If the syntax has no arguments, it should parse its command name as arg1
    return { arg1: match.to_a.first } if args.empty?

    Hash[*[:arg1, :arg2].zip(args).flatten]
  end
end

return if $0 != __FILE__

require 'test/unit'
include Test::Unit::Assertions

# Test two-argument syntax
syntax = HvmSyntax.new(/push (local) (\d)/, :C_PUSH)
assert_equal :C_PUSH, syntax.type
assert syntax.applies_to?('push local 0')
assert !syntax.applies_to?('push local')
assert !syntax.applies_to?('push 0')
assert !syntax.applies_to?('push 0 local')
assert !syntax.applies_to?('pop local 0')

assert_equal 'local', syntax.parse_args('push local 0')[:arg1]
assert_equal '0',     syntax.parse_args('push local 0')[:arg2]
assert_equal 0,       syntax.parse_args('pop local 0').length

# Test one-argument syntax
syntax = HvmSyntax.new(/goto (\w+)/, :C_GOTO)
assert syntax.applies_to?('goto label')
assert_equal 'label', syntax.parse_args('goto label')[:arg1]
assert_equal nil,     syntax.parse_args('goto label')[:arg2]

# Test no-argument syntax
syntax = HvmSyntax.new(/eq/, :C_ARITHMETIC)
assert !syntax.applies_to?('equal')
assert_equal 'eq', syntax.parse_args('eq')[:arg1]
