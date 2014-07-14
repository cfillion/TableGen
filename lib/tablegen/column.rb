# Instances of this class are created automatically by {TableGen#column TableGen#column}.
class TableGen::Column
  # The alignment of the row fields.
  # Possible values:
  # - :left
  # - :center
  # - :right
  #
  # (Defaults to *:left*)
  #
  # @return [Symbol]
  # @see #header_alignment
  attr_accessor :alignment

  # Whether the column can be hidden to respect the table's width constraint.
  # (Defaults to *false*)
  #
  # @return [Boolean]
  attr_accessor :collapse

  # The row formatter. The default block returns the original data.
  #
  # @example Progress Bar
  #   # formats 0.4 to [####      ]
  #   column.format = proc {|fraction, width_hint|
  #     fill_width = width_hint - 2 # bar borders
  #     repeat = fraction * fill_width
  #     "[%-#{fill_width}s]" % ['#' * repeat]
  #   }
  #   # works best with:
  #   column.min_width = 12
  #   column.stretch = true
  #
  # @param [Object] data whatever you passed to {TableGen#row}
  # @param [Fixnum] width_hint
  # @return [Proc]
  attr_accessor :format

  # The alignment of the header fields. Possible values:
  # - :auto (row alignment)
  # - :left
  # - :center
  # - :right
  #
  # (Defaults to *:auto*)
  #
  # @return [Symbol]
  #
  # @see #alignment
  attr_accessor :header_alignment

  # The column's minimum width (in characters).
  # (Defaults to *0*)
  #
  # @return [Fixnum]
  attr_accessor :min_width

  # The field padding character.
  # (Defaults to a space)
  # 
  # @return [String]
  attr_accessor :padding

  # Whether to stretch the column to fill the table's width constraint.
  # (Defaults to *false*)
  #
  # @return [Boolean]
  attr_accessor :stretch

  def initialize
    @alignment = :left
    @collapse = false
    @format = proc {|data| data }
    @header_alignment = :auto
    @min_width = 0
    @padding = "\x20"
    @stretch = false
  end
end
