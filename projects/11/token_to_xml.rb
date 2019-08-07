
require_relative 'jack/modules/jack_tokenizer'

def xml_safe(string)
  string.gsub(/[<>&]/, { '<' => '&lt;', '>' => '&gt;', '&' => '&amp;' })
end

src_path = ARGV[0]
tokenizer = JackTokenizer.new(File.open(src_path, mode='r').read)

puts "<tokens>"
while tokenizer.has_more_tokens?
  tokenizer.advance
  case tokenizer.token_type
  when :KEYWORD
    puts "<keyword> #{tokenizer.keyword.to_s.downcase} </keyword>"

  when :SYMBOL
    puts "<symbol> #{xml_safe(tokenizer.symbol)} </symbol>"

  when :IDENTIFIER
    puts "<identifier> #{tokenizer.identifier} </identifier>"

  when :STRING_CONST
    puts "<stringConstant> #{xml_safe(tokenizer.string_val).tr('"', '')} </stringConstant>"

  when :INT_CONST
    puts "<integerConstant> #{tokenizer.int_val} </integerConstant>"

  when :EOS
    break

  end
end
puts "</tokens>"
