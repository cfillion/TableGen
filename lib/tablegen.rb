require 'tablegen/version'

class TableGen
  class Error < RuntimeError; end

  Column = Struct.new :alignment, :format, :padding, :stretch
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
      col.format = proc {|data| data }
      col.padding = "\x20"
      col.stretch = false

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
      length = real_length format
      width = [width, length].max
    }
    width
  end

  def real_width
    to_s.each_line.map {|l| real_length l.chomp }.max || 0
  end

  def to_s
    validate_table

    table = ''
    @lines.each {|line|
      out = case line.type
      when :row
        format_row line.data
      when :separator
        line.data[0] * width
      when :text
        line.data
      end
      out.rstrip!

      line_length = real_length out
      if @width && line_length > @width
        raise Error, "insufficient width to generate the table"
      end

      table += out + $/
    }
    table.chomp
  end

  private
  def rows
    @lines.select {|l| l.type == :row }
  end

  def format_row(fields)
    out = ''

    fields.each_with_index {|data, index|
      col = column index
      width = column_width index
      field = col.format[data, width]
      length = real_length field

      padding = col.padding[0] * (width - length)

      out += @border unless out.empty?
      out += col.alignment == :left ? field + padding : padding + field
    }
    out
  end

  def column_width(index, can_stretch = true)
    col = column index
    width = 0

    if can_stretch && col.stretch && @width
      other_width = 0
      @columns.each_with_index {|other_col, col_index|
        next if other_col.stretch
        other_width += column_width(col_index, false)
        other_width += real_length @border
      }
      width = @width - other_width
    else
      rows.each {|row|
        data = row.data[index]
        next unless data

        field = col.format[data]
        width = [width, real_length(field)].max
      }
    end
    width
  end

  def validate_table
    stretch_count = 0
    inspected = []
    rows.each {|row|
      row.data.count.times {|col_i|
        next if inspected.include? col_i

        col = column col_i
        stretch_count += 1 if col.stretch
        inspected << col_i
      }
    }

    raise Error, 'only one column can be stretched' if stretch_count > 1
  end

  def real_length(string)
    doublesize = string.scan(/\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/).count
    string.length + doublesize
  end
end
