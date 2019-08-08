require_relative 'jack_symbol_table'
require_relative 'jack_vm_writer'

class JackCompilationEngine
  NULLFILE = File::open(File::NULL, mode='w')

  def initialize(tokens, xml_out: NULLFILE, vm_out: NULLFILE)
    @tokens = tokens

    @xml_out = xml_out
    @vm_writer = JackVmWriter.new(vm_out)

    @symbol_table = JackSymbolTable.new

    @class_name = ''
    @subroutine = nil

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

        @symbol_table.define(var_name, var_type, scope)

        while next?(:SYMBOL, ',')
          pop(:SYMBOL, ',')
          var_name  = pop(:IDENTIFIER)

          @symbol_table.define(var_name, var_type, scope)
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
        name = pop(:IDENTIFIER)

        start_subroutine(kind, return_type, name)

        pop(:SYMBOL, '(')

        compile_parameter_list

        pop(:SYMBOL, ')')

        compile_subroutine_body

      end
    end
  end

  Subroutine = Struct.new(:kind, :return_type, :name, :indices)

  def start_subroutine(kind, return_type, name)
    @subroutine = Subroutine.new(kind, return_type, name, Hash.new(-1))
    @symbol_table.start_subroutine
  end

  def compile_parameter_list
    non_terminal :parameterList do

      if @subroutine.kind == :METHOD
        # Registers a dummy entry to shift index
        # since `this` will be passed implicitly
        @symbol_table.define('this', @class_name, :ARG)
      end

      while next?(:TYPE)
        arg_type = pop(:TYPE)
        arg_name = pop(:IDENTIFIER)

        @symbol_table.define(arg_name, arg_type, :ARG)

        break unless next?(:SYMBOL, ',')

        pop(:SYMBOL, ',')
      end

    end
  end

  def compile_subroutine_body
    non_terminal :subroutineBody do

      pop(:SYMBOL, '{')

      compile_var_dec

      n_locals = @symbol_table.var_count(:VAR)
      @vm_writer.write_function("#{@class_name}.#{@subroutine.name}", n_locals)

      case @subroutine.kind
      when :CONSTRUCTOR
        # Allocate space for the new instance
        @vm_writer.write_push(:CONST, @symbol_table.var_count(:FIELD))
        @vm_writer.write_call('Memory.alloc', 1)
        @vm_writer.write_pop(:POINTER, 0)

      when :METHOD
        # Sets `this` pointer implicitly passed via the first argument
        @vm_writer.write_push(:ARG, 0)
        @vm_writer.write_pop(:POINTER, 0)

      end

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

        @symbol_table.define(var_name, type, :VAR)

        while next?(:SYMBOL, ',')
          pop(:SYMBOL, ',')
          var_name  = pop(:IDENTIFIER)

          @symbol_table.define(var_name, type, :VAR)
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
      kind = @symbol_table.kind_of(var_name)

      if kind == :NONE
        fail "undefined variable: #{var_name}"
      end

      segment = to_segment(kind)
      index = @symbol_table.index_of(var_name)

      if next?(:SYMBOL, '[')
        # Indexer access

        # Gets the base pointer
        @vm_writer.write_push(segment, index)

        pop(:SYMBOL, '[')
        compile_expression
        pop(:SYMBOL, ']')

        # Offsets the pointer
        @vm_writer.write_arithmetic(:ADD)

        pop(:SYMBOL, '=')

        compile_expression

        # Pop the right value from the stack
        # to retrieve the left pointer behind it
        @vm_writer.write_pop(:TEMP, 0)

        # Sets the left pointer to `that`
        @vm_writer.write_pop(:POINTER, 1)

        # Moves the right value to the address the left points
        @vm_writer.write_push(:TEMP, 0)
        @vm_writer.write_pop(:THAT, 0)

      else
        # Simple assign
        pop(:SYMBOL, '=')
        compile_expression
        @vm_writer.write_pop(segment, index)
      end

      pop(:SYMBOL, ';')

    end
  end

  def compile_if_statement
    non_terminal :ifStatement do

      pop(:KEYWORD, :IF)

      @subroutine.indices[:if] += 1
      label_else  = "ELSE_#{@subroutine.indices[:if]}"
      label_endif = "ENDIF_#{@subroutine.indices[:if]}"

      pop(:SYMBOL, '(')
      compile_expression
      pop(:SYMBOL, ')')

      @vm_writer.write_arithmetic(:NOT)
      @vm_writer.write_if(label_else)

      pop(:SYMBOL, '{')
      compile_statements
      pop(:SYMBOL, '}')

      @vm_writer.write_goto(label_endif)
      @vm_writer.write_label(label_else)

      if next?(:KEYWORD, :ELSE)
        pop(:KEYWORD, :ELSE)


        pop(:SYMBOL, '{')
        compile_statements
        pop(:SYMBOL, '}')

      end

      @vm_writer.write_label(label_endif)

    end
  end

  def compile_while_statement
    non_terminal :whileStatement do

      pop(:KEYWORD, :WHILE)

      @subroutine.indices[:while] += 1
      label_while    = "WHILE_#{@subroutine.indices[:while]}"
      label_endwhile = "ENDWHILE_#{@subroutine.indices[:while]}"

      @vm_writer.write_label(label_while)

      pop(:SYMBOL, '(')
      compile_expression
      pop(:SYMBOL, ')')

      @vm_writer.write_arithmetic(:NOT)
      @vm_writer.write_if(label_endwhile)

      pop(:SYMBOL, '{')
      compile_statements
      pop(:SYMBOL, '}')

      @vm_writer.write_goto(label_while)
      @vm_writer.write_label(label_endwhile)

    end
  end

  def compile_do_statement
    non_terminal :doStatement do

      pop(:KEYWORD, :DO)

      subroutine_call(pop(:IDENTIFIER))
      @vm_writer.write_pop(:TEMP, 0) # Discards the return value

      pop(:SYMBOL, ';')

    end
  end

  def compile_return_statement
    non_terminal :returnStatement do

      pop(:KEYWORD, :RETURN)

      if next?(:SYMBOL, ';')
        # Pushes a dummy value to return
        @vm_writer.write_push(:CONST, 0)
      else
        compile_expression
      end

      @vm_writer.write_return

      pop(:SYMBOL, ';')

    end
  end

  def compile_expression
    non_terminal :expression do

      compile_term

      while next?(:SYMBOL, %w[+ - * / & | < > =])
        op = pop(:SYMBOL)
        compile_term

        write_arithmetic(op)
      end

    end
  end

  def write_arithmetic(op_token)
    case op_token
    when '+' then @vm_writer.write_arithmetic(:ADD)
    when '-' then @vm_writer.write_arithmetic(:SUB)
    when '*' then @vm_writer.write_call('Math.multiply', 2)
    when '/' then @vm_writer.write_call('Math.divide', 2)
    when '&' then @vm_writer.write_arithmetic(:AND)
    when '|' then @vm_writer.write_arithmetic(:OR)
    when '<' then @vm_writer.write_arithmetic(:LT)
    when '>' then @vm_writer.write_arithmetic(:GT)
    when '=' then @vm_writer.write_arithmetic(:EQ)
    end
  end

  def to_segment(kind)
    case kind
    when :STATIC then :STATIC
    when :FIELD  then :THIS
    when :ARG    then :ARG
    when :VAR    then :LOCAL
    end
  end

  def compile_expression_list
    n_args = 0
    non_terminal :expressionList do

      next if next?(:SYMBOL, ')') # No argument

      compile_expression
      n_args += 1

      while next?(:SYMBOL, ',')
        pop(:SYMBOL, ',')
        compile_expression
        n_args += 1
      end

    end
    n_args
  end

  def compile_term
    non_terminal :term do

      if next?(:INT_CONST)
        int_val = pop(:INT_CONST)
        @vm_writer.write_push(:CONST, int_val)

      elsif next?(:STRING_CONST)
        str = pop(:STRING_CONST).tr('"', '')

        @vm_writer.write_push(:CONST, str.length + 1)
        @vm_writer.write_call('String.new', 1)
        str.each_char do |char|
          @vm_writer.write_push(:CONST, char.ord)
          @vm_writer.write_call('String.appendChar', 2)
        end

      elsif next?(:KEYWORD, :TRUE)
        pop(:KEYWORD)
        @vm_writer.write_push(:CONST, 0)
        @vm_writer.write_arithmetic(:NOT)

      elsif next?(:KEYWORD, [:FALSE, :NULL])
        pop(:KEYWORD)
        @vm_writer.write_push(:CONST, 0)

      elsif next?(:KEYWORD, [:TRUE, :FALSE, :NULL, :THIS])
        pop(:KEYWORD)
        @vm_writer.write_push(:POINTER, 0)

      elsif next?(:IDENTIFIER)
        identifier = pop(:IDENTIFIER)
        kind = @symbol_table.kind_of(identifier)

        if next?(:SYMBOL, '[')
          # Indexer access
          fail "undefined variable: #{identifier}" if kind == :NONE
          pop(:SYMBOL, '[')
          compile_expression
          pop(:SYMBOL, ']')

          index = @symbol_table.index_of(identifier)
          @vm_writer.write_push(to_segment(kind), index)
          @vm_writer.write_arithmetic(:ADD)
          @vm_writer.write_pop(:POINTER, 1)
          @vm_writer.write_push(:THAT, 0)

        elsif next?(:SYMBOL, ['(', '.'])
          subroutine_call(identifier)

        else
          fail "undefined variable: #{identifier}" if kind == :NONE
          index = @symbol_table.index_of(identifier)
          @vm_writer.write_push(to_segment(kind), index)

        end

      elsif next?(:SYMBOL, '(')
        pop(:SYMBOL, '(')
        compile_expression
        pop(:SYMBOL, ')')

      elsif next?(:SYMBOL, ['-', '~'])
        op = pop(:SYMBOL)
        compile_term

        case op
        when '-' then @vm_writer.write_arithmetic(:NEG)
        when '~' then @vm_writer.write_arithmetic(:NOT)
        end
      end

    end
  end

  def subroutine_call(leftmost)
    subroutine_name = nil
    receiver = nil
    if next?(:SYMBOL, '(')
      subroutine_name = leftmost

    else
      receiver = leftmost
      pop(:SYMBOL, '.')
      subroutine_name = pop(:IDENTIFIER)
    end

    n_args = 0

    if receiver.nil?
      # Calling this.method
      receiver = @class_name
      @vm_writer.write_push(:POINTER, 0)
      n_args += 1

    else
      kind = @symbol_table.kind_of(receiver)
      if kind != :NONE
        # Calling that.method
        # NOTE: Need to deny access field variable from function?
        index = @symbol_table.index_of(receiver)
        receiver = @symbol_table.type_of(receiver)
        @vm_writer.write_push(to_segment(kind), index)
        n_args += 1
      else
        # Calling function (nothing to prepare; just call it!)
      end
    end

    pop(:SYMBOL, '(')
    n_args += compile_expression_list
    pop(:SYMBOL, ')')

    @vm_writer.write_call("#{receiver}.#{subroutine_name}", n_args)

  end

  private
  # Just check the next token without advancing
  def next?(expected_type, expected_tokens = [])
    next_type, next_token = tokenizer{ @tokens.peek }

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
    next_type, next_token, raw = tokenizer{ @tokens.next } # Consumes the next token
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

    expected_tokens = [expected_tokens].flatten
    token_str = expected_tokens.join("' or '")
    error_message = "#{expected_type} '#{token_str}' expected but was #{next_type} '#{next_token}'"

    if !type_valid
      fail error_message
    end

    # Checks token content
    if expected_tokens.empty? || expected_tokens.include?(next_token)
      write_token_as_xml(next_type, next_token)
      next_token
    else
      fail error_message
    end
  end

  def fail(message)
    $stderr.puts "line:#{@current_index}: #{@current_line}"
    raise message
  end

  # Wrapper to catch exceptions from tokenizer
  def tokenizer
    yield

  rescue RangeError, RuntimeError => ex
    $stderr.print 'invalid token detected around '
    fail ex.message
  end

  def non_terminal(tag)
    @xml_out.puts "#{indent}<#{tag}>"
    @nest += 1

    yield

    @nest -= 1
    @xml_out.puts "#{indent}</#{tag}>"
  end

  def write_token_as_xml(type, token)
    tag, token_str = case type
      when :IDENTIFIER   then [type.to_s.downcase, token.to_s]
      when :INT_CONST    then ["integerConstant",  token.to_s]
      when :STRING_CONST then ["stringConstant",   token.tr('"', '')]
      else                    [type.to_s.downcase, token.to_s.downcase]
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
  field boolean valid, pnum, nnum;

  constructor Klass new(int a, int b) {
    var int i, j, k;
    var int min, max;
    var Array list;
    var boolean flag;

    do initialize();
    let i[j] = k;

    if (valid & total = i) {
      do foo(a, this, b);
      do Array.new(true);
    }
    else {
      while ((min < total) | (total < max)) {
        let count = b;
        if (flag) { let b = a + b; }
        else      { return a / b; }
      }
    }

    return total;
  }

  method void task() {
    var Array foo;
    var char bar, baz, bit;
    var int foobar;

    let pnum = 1234;
    let nnum = -3456;
    do foo.bar(baz(), "foo", bar + (3 * -2));
    let foobar = Foo.baz(null, false, foo[bar(baz)]) / ~bit;

    return;
  }
}
EOS

tokenizer = JackTokenizer.new(src)
compiler = JackCompilationEngine.new(tokenizer.to_enum)

# Just checks no exception raised
assert_nothing_raised do
  compiler.compile_class
end
