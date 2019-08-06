
class JackCompilationEngine
  NULLFILE = File::open(File::NULL, mode='w')

  def initialize(tokens, xml_out: NULLFILE, vm_out: NULLFILE)
    @tokens = tokens

    @xml_out = xml_out
    @vm_out = vm_out

    @current_line = ''
    @current_index = 0

    @nest = 0
  end

  def compile_class
    non_terminal :class do

      pop(:KEYWORD, :CLASS)

      @class_name = pop(:IDENTIFIER)

      pop(:SYMBOL, '{')

      compile_class_var_dec

      compile_subroutine_dec

      pop(:SYMBOL, '}')

    end
  end

  def compile_class_var_dec
    while next?(:KEYWORD, [:STATIC, :FIELD])
      non_terminal :classVarDec do

        scope = pop(:KEYWORD)
        var_type  = pop(:TYPE)
        var_name  = pop(:IDENTIFIER)

        # @symbol_table add

        while next?(:SYMBOL, ',')
          pop(:SYMBOL, ',')
          var_name  = pop(:IDENTIFIER)

          # @symbol_table add
        end

        pop(:SYMBOL, ';')

      end
    end
  end

  def compile_subroutine_dec
    while next?(:KEYWORD, [:CONSTRUCTOR, :FUNCTION, :METHOD])
      non_terminal :subroutineDec do

        kind = pop(:KEYWORD)
        return_type = next?(:KEYWORD, :VOID) ? pop(:KEYWORD, :VOID)
                                             : pop(:TYPE)
        subroutine_name = pop(:IDENTIFIER)

        # @symbol_table new_function

        pop(:SYMBOL, '(')

        compile_parameter_list

        pop(:SYMBOL, ')')

        compile_subroutine_body

      end
    end
  end

  def compile_parameter_list
    non_terminal :parameterList do

      while next?(:TYPE)
        arg_type = pop(:TYPE)
        arg_name = pop(:IDENTIFIER)

        # @symbol_table add

        break unless next?(:SYMBOL, ',')

        pop(:SYMBOL, ',')
      end

    end
  end

  def compile_subroutine_body
    non_terminal :subroutineBody do

      pop(:SYMBOL, '{')

      compile_var_dec

      compile_statements

      pop(:SYMBOL, '}')

    end
  end

  def compile_var_dec
    while next?(:KEYWORD, :VAR)
      non_terminal :varDec do

        pop(:KEYWORD, :VAR)
        type  = pop(:TYPE)
        var_name  = pop(:IDENTIFIER)

        # @symbol_table add

        while next?(:SYMBOL, ',')
          pop(:SYMBOL, ',')
          var_name  = pop(:IDENTIFIER)

          # @symbol_table add
        end

        pop(:SYMBOL, ';')

      end
    end
  end

  def compile_statements
    non_terminal :statements do

      while next?(:KEYWORD, [:LET, :IF, :WHILE, :DO, :RETURN])
        if    next?(:KEYWORD, :LET)    then compile_let_statement
        elsif next?(:KEYWORD, :IF)     then compile_if_statement
        elsif next?(:KEYWORD, :WHILE)  then compile_while_statement
        elsif next?(:KEYWORD, :DO)     then compile_do_statement
        elsif next?(:KEYWORD, :RETURN) then compile_return_statement
        end
      end

    end
  end

  def compile_let_statement
    non_terminal :letStatement do

      pop(:KEYWORD, :LET)

      var_name = pop(:IDENTIFIER)

      # Needs to check if the variable exists in this scope?

      # Indexer
      if next?(:SYMBOL, '[')
        pop(:SYMBOL, '[')
        compile_expression
        # Here the stack top should be the value of indexer
        pop(:SYMBOL, ']')
      end

      pop(:SYMBOL, '=')

      compile_expression
      # Here the stack top should be the right value

      pop(:SYMBOL, ';')

    end
  end

  def compile_if_statement
    non_terminal :ifStatement do

      pop(:KEYWORD, :IF)

      pop(:SYMBOL, '(')
      compile_expression
      # Here the stack top should be the condition value
      pop(:SYMBOL, ')')

      pop(:SYMBOL, '{')
      compile_statements
      pop(:SYMBOL, '}')

      if next?(:KEYWORD, :ELSE)
        pop(:KEYWORD, :ELSE)

        pop(:SYMBOL, '{')
        compile_statements
        pop(:SYMBOL, '}')
      end

    end
  end

  def compile_while_statement
    non_terminal :whileStatement do

      pop(:KEYWORD, :WHILE)

      pop(:SYMBOL, '(')
      compile_expression
      # Here the stack top should be the condition value
      pop(:SYMBOL, ')')

      pop(:SYMBOL, '{')
      compile_statements
      pop(:SYMBOL, '}')

    end
  end

  def compile_do_statement
    non_terminal :doStatement do

      pop(:KEYWORD, :DO)

      # Subroutine call
      leftmost = pop(:IDENTIFIER)

      subroutine_name = nil
      receiver = nil
      if next?(:SYMBOL, '(')
        subroutine_name = leftmost

      else
        receiver = leftmost
        pop(:SYMBOL, '.')
        subroutine_name = pop(:IDENTIFIER)
      end

      # Needs to check if the receiver exists in this scope?

      pop(:SYMBOL, '(')
      compile_expression_list
      pop(:SYMBOL, ')')

      pop(:SYMBOL, ';')

    end
  end

  def compile_return_statement
    non_terminal :returnStatement do

      pop(:KEYWORD, :RETURN)

      if !next?(:SYMBOL, ';')
        compile_expression
      end

      pop(:SYMBOL, ';')

    end
  end

  def compile_expression
    non_terminal :expression do

      compile_term

      ops = %w[+ - * / & | < > =]
      while next?(:SYMBOL, ops)
        op = pop(:SYMBOL)
        compile_term
      end

    end
  end

  def compile_expression_list
    non_terminal :expressionList do

      next if next?(:SYMBOL, ')') # No argument

      compile_expression

      while next?(:SYMBOL, ',')
        pop(:SYMBOL, ',')
        compile_expression
      end

    end
  end

  def compile_term
    non_terminal :term do

      # WIP: this is Just enough to pass ExpressionLessSquare test
      if next?(:KEYWORD, [:TRUE, :FALSE, :NULL, :THIS])
        pop(:KEYWORD)

      elsif next?(:IDENTIFIER)
        pop(:IDENTIFIER)
      end

    end
  end

  private
  # Just check the next token without advancing
  def next?(expected_type, expected_tokens = [])
    next_type, next_token = @tokens.peek

    # Checks token type
    primitive = next_type == :KEYWORD && [:INT, :CHAR, :BOOLEAN].include?(next_token)
    type_valid = if expected_type == :TYPE
      primitive || next_type == :IDENTIFIER
    else
      next_type == expected_type
    end

    return false if !type_valid
    return true  if expected_tokens.empty? # No need to check token content

    # Checks token content
    [expected_tokens].flatten.include?(next_token)
  end

  # Get the next token with advancing
  def pop(expected_type, expected_tokens = [])
    next_type, next_token, raw = @tokens.next # Consumes the next token
    @current_line = raw[:line]
    @current_index = raw[:index]

    # Checks token type
    primitive = next_type == :KEYWORD && [:INT, :CHAR, :BOOLEAN].include?(next_token)
    type_valid = if expected_type == :TYPE
      # Variable type consists of diferrent token types
      primitive || next_type == :IDENTIFIER
    else
      next_type == expected_type
    end

    if !type_valid
      fail "token type <#{expected_type}> expected but was <#{next_type}> '#{next_token}'"
    end

    # Checks token content
    expected_tokens = [expected_tokens].flatten
    token_str = expected_tokens.join("' or '")

    if expected_tokens.empty? || expected_tokens.include?(next_token)
      write_token_as_xml(next_type, next_token)
      next_token
    else
      fail "#{expected_type} '#{token_str}' expected but was '#{next_token}'"
    end
  end

  def fail(message)
    $stderr.puts "line:#{@current_index}: #{@current_line}"
    raise message
  end

  def non_terminal(tag)
    @xml_out.puts "#{indent}<#{tag}>"
    @nest += 1

    yield

    @nest -= 1
    @xml_out.puts "#{indent}</#{tag}>"
  end

  def write_token_as_xml(type, token)
    tag = type.to_s.downcase

    token_str = case type
    when :IDENTIFIER, :INT_CONST
      token.to_s
    when :STRING_CONST
      token.tr('"', '')
    else
      token.to_s.downcase
    end

    @xml_out.puts "#{indent}<#{tag}> #{xml_safe(token_str)} </#{tag}>"
  end

  def xml_safe(string)
    string.gsub(/[<>&]/, { '<' => '&lt;', '>' => '&gt;', '&' => '&amp;' })
  end

  def indent
    '  ' * @nest
  end
end

return if $0 != __FILE__

require 'test/unit'
include Test::Unit::Assertions

require_relative 'jack_tokenizer'

src =<<EOS
class Klass {
  static int count, total;
  field boolean valid;

  constructor Klass new(int a, int b) {
    var int i, j, k;
    var Array list;

    do initialize();
    let i[j] = k;

    if (valid & total = f) {
      do foo(a, this, c);
      do Array.new(true);
    }
    else {
      while (cond) {
        let count = b;
        if (flag) { let b = a + b; }
        else      { return; }
      }
    }

    return total;
  }
}
EOS

tokenizer = JackTokenizer.new(src)
compiler = JackCompilationEngine.new(tokenizer.to_enum)

# Just checks no exception raised
assert_nothing_raised do
  compiler.compile_class
end
