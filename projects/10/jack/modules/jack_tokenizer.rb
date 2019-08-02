
class JackTokenizer
  keywords = %w[class constructor function method field static var int char
                boolean void true false null this let do if else while return].join('|')
  symbols  = '{|}|\(|\)|\[|\]|\.|,|;|\+|-|\*|\/|&|\||<|>|=|~'

  Token = Struct.new(:pattern, :type)
  Rules = [
    # Tokens of Jack language
    Token.new(/(?:#{keywords})/,        :KEYWORD),
    Token.new(/(?:#{symbols})/,         :SYMBOL),
    Token.new(/[a-zA-Z_][a-zA-Z0-9_]*/, :IDENTIFIER),
    Token.new(/"[^\r\n]*?"/,            :STRING_CONST),
    Token.new(/[0-9]+\b/,               :INT_CONST),

    # Not tokens but need to be handled properly
    Token.new(%r!//[^\r\n]*!, :COMMENT),
    Token.new(%r!/\*.*?\*/!m, :COMMENT),
    Token.new(/[\t ]+/,       :TAB_SPACE),
    Token.new(/\R/,           :NEWLINE)
  ]

  def initialize(raw_src)
    @src_lines = raw_src.each_line.to_a
    @src = raw_src
    @index = 1

    clear_token
  end
  attr_reader :token_type, :keyword, :symbol,
              :identifier, :int_val, :string_val

  def has_more_tokens?
    !@src.empty?
  end

  def advance
    clear_token

    loop do
      token, match = token_matching(@src)

      if token.nil?
        # No rule matched with the remaining source
        raise "couldn't find a token"
      end

      case token.type
      when :KEYWORD
        @token_type = token.type
        @keyword = match.to_s.upcase.to_sym

      when :SYMBOL
        @token_type = token.type
        @symbol = match.to_s

      when :IDENTIFIER
        @token_type = token.type
        @identifier = match.to_s

      when :INT_CONST
        int_val = match.to_s.to_i
        if (0..32767).include?(int_val)
          @token_type = token.type
          @int_val = int_val
        else
          raise RangeError
        end

      when :STRING_CONST
        @token_type = token.type
        @string_val = match.to_s

      when :NEWLINE
        @index += 1

      when :COMMENT
        # e.g. If there're 4 lines, they have 3 newline characters
        @index += match.to_s.lines.length - 1

      when :TAB_SPACE
        # Nothing to do
      end

      # Consume the source string
      @src = match.post_match

      # Loop until a token is detected
      break unless @token_type.nil?

      if has_more_tokens?
        next
      else
        # Hit the end of the source
        @token_type = :EOS
        break
      end
    end
  end

  def current_line
    @src_lines[@index - 1].chomp
  end

  def current_line_index
    @index
  end

  private
  def clear_token
    @token_type = nil
    @keyword    = nil
    @symbol     = nil
    @identifier = nil
    @int_val    = nil
    @string_val = nil
  end

  def token_matching(string)
    # Test all rules against `string`
    matches = Rules.map{ |token| /\A#{token.pattern}/.match(string) }
    token_with_matches = Rules.zip(matches).reject{ |token, match| match.nil? }
    # Choose the longest match
    token_with_matches.max_by{ |token, match| match.to_s.length }
  end
end

return if $0 != __FILE__

require 'test/unit'
include Test::Unit::Assertions

# Test basic tokens
src =<<EOS
// comment
/* multiple
   line */

class constructor function method field static var int char
bloolean void true false null this let do if else while return

{ ( [ .,;+-*/&|<>=~ ] ) }
0
-1234
32767
foo bar2 _b_a_z
"foobarbaz123"
EOS

tokenizer = JackTokenizer.new(src)
assert_nothing_raised do
  tokenizer.advance while tokenizer.has_more_tokens?
end

# int_val should return Integer(not String)
tokenizer = JackTokenizer.new("32767")
tokenizer.advance
assert_equal 32767, tokenizer.int_val

# Integer value should be within (0..32767)
tokenizer = JackTokenizer.new("32768")
assert_raise(RangeError) do
  tokenizer.advance
end

# Identifier cannot start with a number
tokenizer = JackTokenizer.new("123invalid_token")
exception = assert_raise(RuntimeError) do
  tokenizer.advance
end
assert_equal "couldn't find a token", exception.message

# String cannot include newline characters
src =<<EOS
"string with
newline"
EOS
tokenizer = JackTokenizer.new(src)
exception = assert_raise(RuntimeError) do
  tokenizer.advance
end
assert_equal "couldn't find a token", exception.message

# String cannot include double quotations
tokenizer = JackTokenizer.new('"this is " string"')
exception = assert_raise(RuntimeError) do
  tokenizer.advance while tokenizer.has_more_tokens?
end
assert_equal "couldn't find a token", exception.message

# Comment separetes tokenss
tokenizer = JackTokenizer.new("foo/* bar */baz")
tokenizer.advance
assert_equal 'foo', tokenizer.identifier
tokenizer.advance
assert_equal 'baz', tokenizer.identifier

# Test current line
src =<<EOS

//
/*
 * comment

 */

class Main { ... }
EOS

tokenizer = JackTokenizer.new(src)
tokenizer.advance
assert_equal 8, tokenizer.current_line_index
assert_equal "class Main { ... }", tokenizer.current_line

# Test comment on the botton
src =<<EOS

class Main { ... }
//
/*
 * comment

 */

EOS

tokenizer = JackTokenizer.new(src)
assert_nothing_raised do
  tokenizer.advance while tokenizer.has_more_tokens?
end
assert_equal :EOS, tokenizer.token_type

# Test comment only
src =<<EOS

//
/*
 * comment

 */

EOS

tokenizer = JackTokenizer.new(src)
assert_nothing_raised do
  tokenizer.advance
end
assert_equal :EOS, tokenizer.token_type
