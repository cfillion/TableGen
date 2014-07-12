require 'tablegen/version'

class TableGen
  Column = Struct.new :alignment, :padding, :format
  Line = Struct.new :type, :data

  attr_accessor :border
  attr_writer   :width

  def initialize
    @border = "\x20"
    @columns = []
    @lines = []
  end

  def column(index)
    unless col = @columns[index]
      col = Column.new
      col.alignment = :left
      col.padding = "\x20"
      col.format = proc {|data| data }

      @columns[index] = col
    end

    yield col if block_given?
    col
  end

  def row(*fields)
    raise ArgumentError, 'wrong number of arguments (0 for 1+)' if fields.empty?
    @lines << Line.new(:row, fields)
  end

  def separator(char = '=')
    @lines << Line.new(:separator, char)
  end

  def text(text)
    @lines << Line.new(:text, text)
  end

  def clear
    @lines.clear
  end

  def clear!
    clear
    @columns.clear
  end

  def height
    @lines.count
  end

  def width
    return @width if @width

    width = 0
    rows.each {|row|
      format = format_row row.data
      width = [width, format.length].max
    }
    width
  end

  def real_width
    to_s.each_line.map {|l| l.chomp.length }.max || 0
  end

  def to_s
    output = ''
    @lines.each {|line|
      content = case line.type
      when :row
        format_row line.data
      when :separator
        line.data[0] * width
      when :text
        line.data
      end
      output += content.rstrip + $/
    }
    output.chomp
  end

  private
  def rows
    @lines.select {|l| l.type == :row }
  end

  def format_row(fields)
    out = ''
    fields.each_with_index {|data, index|
      col = column index
      field = col.format[data]
      padding = col.padding[0] * (column_width(index) - field.length)

      out += @border unless out.empty?
      out += col.alignment == :left ? field + padding : padding + field
    }
    out
  end

  def column_width(index)
    col = column index

    width = 0
    rows.each {|row|
      data = row.data[index]
      next unless data

      field = col.format[data]
      width = [width, field.length].max
    }
    width
  end
end
