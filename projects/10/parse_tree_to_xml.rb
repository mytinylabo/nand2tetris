require_relative 'jack/modules/jack_tokenizer'
require_relative 'jack/modules/jack_compilation_engine'

src_path = ARGV[0]

tokens = JackTokenizer.new(File.open(src_path, mode='r').read).to_enum
compiler = JackCompilationEngine.new(tokens, xml_out: $stdout)

compiler.compile_class
