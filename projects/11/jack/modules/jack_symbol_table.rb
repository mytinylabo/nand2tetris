
class JackSymbolTable
  # This order defines prority of variable scope: left over right
  VarKinds = [:ARG, :VAR, :FIELD, :STATIC]

  def initialize
    @table = {}
    @table[:STATIC] = {}
    @table[:FIELD]  = {}
    @table[:ARG] = {}
    @table[:VAR] = {}
  end

  def start_subroutine
    @table[:ARG] = {}
    @table[:VAR] = {}
  end

  def define(name, type, kind)
    @table[kind][name] = type
  end

  def var_count(kind)
    @table[kind].size
  end

  def kind_of(name)
    kind = [:ARG, :VAR, :FIELD, :STATIC].find { |k| @table[k].has_key?(name) }
    kind || :NONE
  end

  def type_of(name)
    @table[kind_of(name)][name]
  end

  def index_of(name)
    @table[kind_of(name)].keys.index(name)
  end
end

return if $0 != __FILE__

require 'test/unit'
include Test::Unit::Assertions

table = JackSymbolTable.new
table.define('foo', :BOOLEAN, :STATIC)

assert_equal 1, table.var_count(:STATIC)
assert_equal :STATIC, table.kind_of('foo')
assert_equal :BOOLEAN, table.type_of('foo')
assert_equal 0, table.index_of('foo')

table.define('foo', :INT, :FIELD)
assert_equal 1, table.var_count(:FIELD)
assert_equal :FIELD, table.kind_of('foo')
assert_equal :INT, table.type_of('foo')
assert_equal 0, table.index_of('foo')

table.define('foo', :CHAR, :VAR)
assert_equal 1, table.var_count(:VAR)
assert_equal :VAR, table.kind_of('foo')
assert_equal :CHAR, table.type_of('foo')
assert_equal 0, table.index_of('foo')

table.define('foo', 'Data', :ARG)
assert_equal 1, table.var_count(:ARG)
assert_equal :ARG, table.kind_of('foo')
assert_equal 'Data', table.type_of('foo')
assert_equal 0, table.index_of('foo')

table.define('bar', :INT, :VAR)
assert_equal 2, table.var_count(:VAR)
assert_equal :VAR, table.kind_of('bar')
assert_equal :INT, table.type_of('bar')
assert_equal 1, table.index_of('bar')
