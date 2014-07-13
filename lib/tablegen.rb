require 'tablegen/version'

class TableGen
  class Error < RuntimeError; end
  class WidthError < Error; end

  Column = Struct.new :alignment, :collapse, :format, :min_width, :padding, :stretch
  Line = Struct.new :type, :data

  attr_accessor :border
  attr_writer   :width

  def initialize
    @border = "\x20"
    @columns = []
    @lines = []
    @collapsed = []
  end

  def column(index)
    unless col = @columns[index]
      col = Column.new
      col.alignment = :left
      col.collapse = false
      col.format = proc {|data| data }
      col.min_width = 0
      col.padding = "\x20"
      col.stretch = false

      @columns[index] = col
    end

    yield col if block_given?
    col
  end

  def columns(*indexes, &block)
    indexes.each {|index|
      column index, &block
    }
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
    create_columns

    table = ''
    @collapsed.clear

    loop do
      table, missing_space = generate_table
      break if missing_space == 0

      candidates = []
      @columns.each_with_index {|col, index|
        if col.collapse && !@collapsed.include?(index)
          candidates << index
        end
      }

      if candidates.empty?
        raise WidthError, "insufficient width to generate the table"
      end

      @collapsed << candidates.min_by {|index|
        (column_width(index, false) - missing_space).abs
      }
    end

    table
  end

  private
  def rows
    @lines.select {|l| l.type == :row }
  end

  def real_length(string)
    doublesize = string.scan(/\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/).count
    string.length + doublesize
  end

  def format_row(fields)
    out = ''

    fields.each_with_index {|data, index|
      next if @collapsed.include? index
      col = column index

      width = column_width index
      field = col.format[data, width]
      length = real_length field

      padding = col.padding[0] * (width - length)

      out += @border unless out.empty?
      out += col.alignment == :left ?
        field + padding :
        padding + field
    }
    out
  end

  def column_width(index, can_stretch = true)
    col = column index

    stretch_index = @columns.find_index {|c|
      c.stretch && !@collapsed.include?(@columns.index(c))
    }

    if can_stretch && index == stretch_index && @width
      other_width = 0
      @columns.each_with_index {|dist_col, dist_index|
        next if dist_index == stretch_index || @collapsed.include?(dist_index)

        other_width += column_width(dist_index, false)
        other_width += real_length @border
      }

      remaining_width = @width - other_width
      needed_width = column_width index, false
      [remaining_width, needed_width].max
    else
      sizes = []
      rows.each {|row|
        data = row.data[index]
        next unless data

        length = real_length col.format[data, col.min_width]
        sizes << [col.min_width, length].max
      }
      sizes.max
    end
  end

  def create_columns
    rows.each {|row|
      row.data.count.times {|col_i|
        column col_i
      }
    }
  end

  def generate_table
    table = ''
    missing_space = [0]

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
      missing_space << line_length - @width if @width

      table += out + $/
    }

    return table.chomp, missing_space.max
  end
end
