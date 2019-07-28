
class HasmParser
  module PTN
    SYMBOL = '([a-zA-Z_.$:][a-zA-Z0-9_.$:]+)'
    NUMSYM = '((?:[0-9]+)|(?:[a-zA-Z_.$:][a-zA-Z0-9_.$:]+))'
    DEST   = '(?:(A?M?D?)=)'
    AMD    = '([-!]?A|[-!]?M|[-!]?D)'
    AMD01  = '(A|M|D|0|1|-1)'
    AMD01S = '([-!]?A|[-!]?M|[-!]?D|0|1|-1)'
    JUMPS  = '(JGT|JEQ|JGE|JLT|JNE|JLE|JMP)'
    OPES   = '([+\-&|])'
  end

  def initialize(raw_src)
    @src_lines = raw_src.each_line.with_index

    @line = ''
    @index = 0

    clear_command
  end
  attr_reader :command_type, :symbol, :dest, :comp, :jump

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
    clear_command

    @line, @index = next_line
    stripped_line = strip(@line)

    case stripped_line
    when /^@#{PTN::NUMSYM}$/
      # A operation
      expr, symbol = Regexp.last_match.to_a

      @command_type = :A_COMMAND
      @symbol = symbol

    when /^\(#{PTN::SYMBOL}\)$/
      # Label (pseudo operation)
      expr, symbol = Regexp.last_match.to_a

      @command_type = :L_COMMAND
      @symbol = symbol

    when /^#{PTN::DEST}?(?:#{PTN::AMD01S}|(?:#{PTN::AMD}#{PTN::OPES}#{PTN::AMD01}))(?:;#{PTN::JUMPS})?$/
      # C operation
      expr, dest, value, left, ope, right, jump = Regexp.last_match.to_a

      @command_type = :C_COMMAND
      @dest = dest || ''
      @comp = value ? value : left + ope + right
      @jump = jump || ''

    else
      put_current_line
      raise 'syntax error'
    end
  end

  def put_current_line
    puts "line:#{@index}| #{@line}"
  end

  private
  def clear_command
    @command_type = nil
    @symbol = nil
    @dest = nil
    @comp = nil
    @jump = nil
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
    line.gsub(/\/\/.*$/, '')
        .gsub(/ +/, '')
        .chomp
  end
end

module HasmCode
  def self.dest(mnemonic)
    code = 0
    code |= 0b100 if mnemonic.include?('A')
    code |= 0b010 if mnemonic.include?('D')
    code |= 0b001 if mnemonic.include?('M')
    code
  end

  def self.comp(mnemonic)
    code = case mnemonic
      when  '0'  then 0b0101010
      when  '1'  then 0b0111111
      when '-1'  then 0b0111010
      when  'D'  then 0b0001100
      when  'A'  then 0b0110000
      when  'M'  then 0b1110000
      when '!D'  then 0b0001101
      when '!A'  then 0b0110001
      when '!M'  then 0b1110001
      when '-D'  then 0b0001111
      when '-A'  then 0b0110011
      when '-M'  then 0b1110011
      when 'D+1' then 0b0011111
      when 'A+1' then 0b0110111
      when 'M+1' then 0b1110111
      when 'D-1' then 0b0001110
      when 'A-1' then 0b0110010
      when 'M-1' then 0b1110010
      when 'D+A' then 0b0000010
      when 'D+M' then 0b1000010
      when 'D-A' then 0b0010011
      when 'D-M' then 0b1010011
      when 'A-D' then 0b0000111
      when 'M-D' then 0b1000111
      when 'D&A' then 0b0000000
      when 'D&M' then 0b1000000
      when 'D|A' then 0b0010101
      when 'D|M' then 0b1010101
      else
        return nil
      end
    code
  end

  def self.jump(mnemonic)
    code = case mnemonic
      when ''    then 0b000
      when 'JGT' then 0b001
      when 'JEQ' then 0b010
      when 'JGE' then 0b011
      when 'JLT' then 0b100
      when 'JNE' then 0b101
      when 'JLE' then 0b110
      when 'JMP' then 0b111
      else
        return nil
      end
    code
  end
end

class HasmSymbolTable
  def initialize
    @table = {
      # Reserved symbols
      'SP'     => 0x0000,
      'LCL'    => 0x0001,
      'ARG'    => 0x0002,
      'THIS'   => 0x0003,
      'THAT'   => 0x0004,
      'R0'     => 0x0000,
      'R1'     => 0x0001,
      'R2'     => 0x0002,
      'R3'     => 0x0003,
      'R4'     => 0x0004,
      'R5'     => 0x0005,
      'R6'     => 0x0006,
      'R7'     => 0x0007,
      'R8'     => 0x0008,
      'R9'     => 0x0009,
      'R10'    => 0x000a,
      'R11'    => 0x000b,
      'R12'    => 0x000c,
      'R13'    => 0x000d,
      'R14'    => 0x000e,
      'R15'    => 0x000f,
      'SCREEN' => 0x4000,
      'KBD'    => 0x6000
    }
  end

  def add_entry(symbol, address)
    @table[symbol] = address
  end

  def contains?(symbol)
    @table.has_key?(symbol)
  end

  def get_address(symbol)
    @table[symbol]
  end
end
