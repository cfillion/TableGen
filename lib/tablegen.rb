require 'tablegen/version'
require 'tablegen/column'

# Copyright (C) 2014 by Christian Fillion
#
# TableGen is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
class TableGen
  # Base class for exceptions.
  class Error < RuntimeError; end

  # Raised when the table cannot respect the width constraint.
  class WidthError < Error; end

  # @api private
  Header = Struct.new :name

  # @api private
  Line = Struct.new :type, :data

  # @attribute border [rw] The column separator.
  #   May be of any length. Defaults to a space.
  #
  #   @return [String]
  attr_accessor :border
  attr_writer   :width

  def initialize
    @border = "\x20"
    @columns = []
    @lines = []
    @collapsed = []
  end

  # Yields and returns the column at the specified index.
  #
  # @example Change the alignment of the first column
  #   table.column 0 do |col|
  #     col.alignment = :right
  #   end
  #
  # @param index [Fixnum]
  # @yield [Column column] the requested column
  # @return [Column] the requested column
  #
  # @see #columns
  # @see Column
  def column(index)
    unless col = @columns[index]
      if @columns.count < index
        # create columns so the holes are not filled with nil
        (@columns.count..index).each {|i| column i }
      end

      col = Column.new index
      @columns[index] = col
    end

    yield col if block_given?
    col
  end

  # Shorthand to {#column}: Yields specified columns.
  #
  # @example Allow columns 6 and 8 to be collapsed
  #   table.columns 6, 8 do |col|
  #     col.collapse = true
  #   end
  #
  # @param [Array<Fixnum>] indexes
  # @yield [Column column] a column from the index list
  #
  # @see #column
  # @see Column
  def columns(*indexes, &block)
    indexes.each {|index|
      column index, &block
    }
  end

  # Add a row to the table. The fields are formatted with {Column#format}.
  #
  # @example
  #   table.column 2 do |col|
  #     col.format = proc {|price|
  #       "$%.2f" % price
  #     }
  #   end
  #
  #   # Product Name, Quantity, Price
  #   table.row 'Table Generator', 42, 0
  #
  # @param [Array<Object>] fields
  # @raise [ArgumentError] at least one field is required
  #
  # @see #header
  def row(*fields)
    raise ArgumentError, 'wrong number of arguments (0 for 1+)' if fields.empty?
    @lines << Line.new(:row, fields)
  end

  # Add a header row to the table. The fields are not formatted.
  #
  # @example
  #   table.header 'Product Name', 'Quantity', 'Price'
  #
  # @param [Array<String>] fields
  # @raise [ArgumentError] at least one field is required
  #
  # @see #row
  def header(*fields)
    row *fields.map {|name| Header.new name }
  end

  # Add a separator to the table.
  #
  # @param [String] char the character to repeat
  def separator(char = '=')
    @lines << Line.new(:separator, char)
  end

  # Add a text line to the table.
  # The text is wrapped automatically to fit into the table.
  #
  # @param line [String]
  def text(line)
    @lines << Line.new(:text, line)
  end

  # Empty the table. Columns settings are conserved.
  #
  # @see #clear!
  def clear
    @lines.clear
  end

  # Empty the table AND delete the columns.
  #
  # @see #clear
  def clear!
    clear
    @columns.clear
  end

  # The maximum width (in characters) of the table.
  # If unspecified (nil), returns the space required to display every row and header.
  #
  # @example Fit the table in the terminal
  #   if STDOUT.tty?
  #     table.width = STDOUT.winsize[1]
  #   end
  #
  # @return [Fixnum]
  #
  # @see #real_width
  def width
    return @width unless @width.nil?

    width = 0
    rows.each {|row|
      format = format_row row.data
      length = real_length format
      width = [width, length].max
    }
    width
  end

  # Calculates the exact width (in characters) of the entire table.
  #
  # @return [Fixnum]
  #
  # @see #width
  def real_width
    to_s.each_line.map {|l| real_length l.chomp }.max || 0
  end

  # The minimum height (in lines) of the table.
  # @note Does not calculate wrapped text lines. If required, use {#real_height} instead.
  #
  # @!attribute [r] height
  # @return [Fixnum]
  #
  # @see #real_height
  def height
    @lines.count
  end

  # Calculates the exact height (in lines) of the table.
  #
  # @return [Fixnum]
  #
  # @see #height
  def real_height
    to_s.lines.count
  end

  # Generate the table.
  #
  #   begin
  #     puts table
  #   rescue TableGen::WidthError
  #     puts 'Terminal is too small'
  #   end
  #
  # @return [String] the table
  # @raise [WidthError] if the table is too large to fit in the {#width} constraint
  # @raise [Error] if something is wrong (eg. invalid column alignment)
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
