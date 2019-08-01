
class JackTokenizer
  keywords = %w[class constructor function method field static var int char
                bloolean void true false null this let do if else while return].join('|')
  symbols  = '{|}|\(|\)|\[|\]|\.|,|;|\+|-|\*|\/|&|\||<|>|=|~'

  Token = Struct.new(:pattern, :type)
  Rules = [
    Token.new(/(?:#{keywords})/,        :KEYWORD),
    Token.new(/(?:#{symbols})/,         :SYMBOL),
    Token.new(/[a-zA-Z_][a-zA-Z0-9_]*/, :IDENTIFIER),
    Token.new(/"[^\r\n]*?"/,            :STRING_CONST),
    Token.new(/[0-9]+\b/,               :INT_CONST),
    Token.new(%r!//[^\r\n]*!,           :COMMENT),
    Token.new(%r!/\*.*?\*/!,            :COMMENT),
    Token.new(/[\t ]+/,                 :TAB_SPACE),
    Token.new(/\R/,                     :NEWLINE)
  ]

  def initialize(raw_src)
    @src_lines = raw_src.each_line.to_a
    @src = raw_src.lstrip
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
        int = match.to_s.to_i
        if (0..32767).include?(int)
          @token_type = token.type
          @int_val = match.to_s
        else
          raise RangeError
        end

      when :STRING_CONST
        @token_type = token.type
        @string_val = match.to_s

      when :NEWLINE
        @index += 1

      when :COMMENT, :TAB_SPACE
        # Nothing to do
      end

      @src = match.post_match
      break unless @token_type.nil? && has_more_tokens?
    end
  end

  def current_line
    "line:#{@index}: #{@src_lines[@index - 1]}"
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
    matches = Rules.map{ |token| /\A#{token.pattern}/.match(string) }
    token_with_matches = Rules.zip(matches).reject{ |token, match| match.nil? }
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

assert_nothing_raised do
  tokenizer = JackTokenizer.new(src)
  tokenizer.advance while tokenizer.has_more_tokens?
end

# Integer value should be within (0..32767)
assert_raise(RangeError) do
  tokenizer = JackTokenizer.new("32768")
  tokenizer.advance
end

# Identifier cannot start with a number
exception = assert_raise(RuntimeError) do
  tokenizer = JackTokenizer.new("123invalid_token")
  tokenizer.advance
end
assert_equal exception.message, "couldn't find a token"

# Comment separetes tokens
tokenizer = JackTokenizer.new("foo/* bar */baz")
tokenizer.advance
assert_equal tokenizer.identifier, 'foo'
tokenizer.advance
assert_equal tokenizer.identifier, 'baz'
