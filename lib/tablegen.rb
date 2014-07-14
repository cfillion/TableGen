require 'tablegen/version'

class TableGen
  class Error < RuntimeError; end
  class WidthError < Error; end

  Column = Struct.new \
    :alignment,
    :collapse,
    :format,
    :header_alignment,
    :min_width,
    :padding,
    :stretch

  Header = Struct.new \
    :name

  Line = Struct.new \
    :type,
    :data

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
      if @columns.count < index
        # create columns so the holes are not filled with nil
        (@columns.count..index).each {|i| column i }
      end

      col = Column.new
      col.alignment = :left
      col.collapse = false
      col.format = proc {|data| data }
      col.header_alignment = :auto
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

  def header(*fields)
    row *fields.map {|name| Header.new name }
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
      table, missing_width = generate_table
      break if missing_width == 0

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
        (column_width(index, false) - missing_width).abs
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
      field = format_field(col, data, width)
      length = real_length field

      pad_width = width - length
      padding = col.padding[0] * pad_width

      alignment = if data.is_a?(Header) && col.header_alignment != :auto
        col.header_alignment
      else
        col.alignment
      end

      out += @border unless out.empty?
      out += \
      case alignment
      when :left
        field + padding
      when :right
        padding + field
      when :center
        left = pad_width / 2
        right = left + (pad_width % 2)
        padding[0...left] + field + padding[0...right]
      else
        raise Error, "invalid alignment '%s'" % col.alignment
      end
    }
    out
  end

  def column_width(index, can_stretch = true)
    col = column index

    stretch_index = @columns.find_index {|c|
      c.stretch && !@collapsed.include?(@columns.index(c))
    }

    if can_stretch && index == stretch_index && @width
      used_width = 0
      @columns.each_with_index {|dist_col, dist_index|
        next if dist_index == stretch_index || @collapsed.include?(dist_index)

        dist_width = column_width(dist_index, false)
        next if dist_width.nil?

        used_width += dist_width
        used_width += real_length @border
      }

      remaining_width = @width - used_width
      needed_width = column_width index, false
      [remaining_width, needed_width].max
    else
      sizes = []
      rows.each {|row|
        data = row.data[index]
        next unless data

        length = real_length format_field(col, data, col.min_width)
        sizes << [col.min_width, length].max
      }
      sizes.max
    end
  end

  def format_field(column, data, width)
    if data.is_a? Header
      data.name
    else
      column.format[data, width]
    end
  end

  def create_columns
    rows.each {|row|
      # creates all columns up to the specified index
      column row.data.count - 1
    }
  end

  def generate_table
    table = ''
    missing_width = [0]

    @lines.each {|line|
      out = case line.type
      when :row
        format_row line.data
      when :separator
        line.data[0] * width
      when :text
        if width > 0
          line.data.scan(/.{1,#{width}}/).join $/
        else
          line.data
        end
      end
      out.rstrip!

      if line.type == :row
        line_length = real_length out
        missing_width << line_length - @width if @width
      end

      table += out + $/
    }

    return table.chomp, missing_width.max
  end
end
