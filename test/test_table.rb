require File.expand_path '../helper', __FILE__

class TestTable < MiniTest::Test
  def setup
    @gen = TableGen.new
  end

  def test_row
    assert_equal 0, @gen.height
    assert_empty @gen.to_s

    @gen.row 'test1', 'test2'
    assert_equal 1, @gen.height

    @gen.row 'test3', 'test4'

    assert_equal 2, @gen.height
    assert_equal 'test1 test2' + $/ + 'test3 test4', @gen.to_s
  end

  def test_width
    assert_equal 0, @gen.width
    assert_equal 0, @gen.real_width

    @gen.row 'test'

    assert_equal 4, @gen.width
    assert_equal 4, @gen.real_width

    @gen.width = 100

    assert_equal 100, @gen.width
    assert_equal 4, @gen.real_width
  end

  def test_no_row
    error = assert_raises ArgumentError do
      @gen.row
    end

    assert_equal 'wrong number of arguments (0 for 1+)', error.message
  end

  def test_column
    col = @gen.column 0
    assert_equal :left, col.alignment
    assert_equal "\x20", col.padding

    block_param = nil
    @gen.column 0 do |col|
      block_param = col
    end
    assert_equal col, block_param
    
    input = 'test'
    assert_same input, col.format[input]
  end

  def test_clear
    @gen.row 'test'

    @gen.column 0 do |col|
      col.padding = 'not cleared'
    end

    refute_equal 0, @gen.height
    assert_equal 'not cleared', @gen.column(0).padding
    @gen.clear

    assert_equal 0, @gen.height
    assert_equal 'not cleared', @gen.column(0).padding
    assert_empty @gen.to_s
  end

  def test_clear!
    @gen.row 'test'

    @gen.column 0 do |col|
      col.padding = 'cleared'
    end

    refute_equal 0, @gen.height
    assert_equal 'cleared', @gen.column(0).padding
    @gen.clear!

    assert_empty @gen.to_s
    assert_equal 0, @gen.height
    refute_equal 'cleared', @gen.column(0).padding
  end
  
  def test_align_left
    @gen.row('long_text', 'short')
    @gen.row('short', 'long_text')

    assert_equal \
      'long_text short' + $/ +
      'short     long_text', @gen.to_s
  end

  def test_align_right
    @gen.row('long_text', 'short')
    @gen.row('short', 'long_text')

    col = @gen.column 1 do |col|
      col.alignment = :right
    end

    assert_equal \
      'long_text     short' + $/ +
      'short     long_text', @gen.to_s
  end

  def test_align_cjk
    @gen.row('新世界より', 'from')
    @gen.row('the', 'new world')

    assert_equal \
      '新世界より from' + $/ +
      'the        new world', @gen.to_s
  end

  def test_custom_padding
    @gen.row('long_text', 'short')
    @gen.row('short', 'long_text')

    @gen.column 0 do |col|
      col.padding = '_'
    end

    @gen.column 1 do |col|
      col.padding = '-='
    end

    assert_equal \
      'long_text short----' + $/ +
      'short____ long_text', @gen.to_s
  end

  def test_holes
    @gen.row('long_text', 'short')
    @gen.row('short')

    assert_equal \
      'long_text short' + $/ +
      'short', @gen.to_s
  end

  def test_separator
    @gen.separator '='
    assert_equal '', @gen.to_s

    @gen.row 'long_text', 'long_text'
    @gen.row'short', 'short'
    @gen.separator '-='

    assert_equal \
      '===================' + $/ +
      'long_text long_text' + $/ +
      'short     short' + $/ +
      '-------------------', @gen.to_s
  end

  def test_separator_fixed_width
    @gen.width = 100

    assert_equal 0, @gen.height
    @gen.separator '='
    assert_equal 1, @gen.height

    assert_equal '='*100, @gen.to_s
  end

  def test_custom_border
    @gen.border = '-|-'
    @gen.row('long_text', 'short')
    @gen.row('short', 'long_text')

    assert_equal \
      'long_text-|-short' + $/ +
      'short    -|-long_text', @gen.to_s
  end

  def test_custom_format
    @gen.row('test', 0.42)
    @gen.row('test', 0.5678)

    sizes = []
    @gen.column 1 do |col|
      col.format = proc {|data, width|
        sizes << width
        "%d%%" % [data * 100]
      }
    end

    assert_equal \
      'test 42%' + $/ +
      'test 56%', @gen.to_s
    assert_equal [0, 3], sizes.uniq
  end

  def test_stretch
    @gen.row('test1', 'test2')
    @gen.row('test3', 'test4')

    @gen.column 0 do |col|
      col.stretch = true
    end

    assert_equal \
      'test1 test2' + $/ +
      'test3 test4', @gen.to_s

    @gen.width = 20

    assert_equal \
      'test1          test2' + $/ +
      'test3          test4', @gen.to_s
  end

  def test_stretch_long_border
    @gen.row('test1', 'test2')
    @gen.row('test3', 'test4')

    @gen.column 0 do |col|
      col.stretch = true
    end

    @gen.width = 20
    @gen.border = '-||-'

    assert_equal \
      'test1      -||-test2' + $/ +
      'test3      -||-test4', @gen.to_s
  end

  def test_stretch_format
    @gen.row('-')
    @gen.row('-', 'test')

    sizes = []
    @gen.column 0 do |col|
      col.stretch = true
      col.format = proc {|data, width|
        sizes << width
        data * width
      }
    end

    @gen.width = 20

    assert_equal \
      '---------------' + $/ +
      '--------------- test', @gen.to_s

    assert_equal [0, 15], sizes.uniq
  end

  def test_spread_stretch
    @gen.row('test', 'test')

    @gen.column 0 do |col|
      col.stretch = true
    end

    @gen.column 1 do |col|
      col.stretch = true
    end

    @gen.width = 20

    error = assert_raises TableGen::Error do
      @gen.to_s
    end

    assert_equal 'only one column can be stretched', error.message
  end

  def test_text
    assert_equal 0, @gen.height
    @gen.text 'Hello World!  '
    assert_equal 1, @gen.height

    assert_equal 'Hello World!', @gen.to_s
    assert_equal 0, @gen.width
    assert_equal 12, @gen.real_width
  end

  def test_table_outgrow
    @gen.width = 2
    @gen.row 'too long'

    error = assert_raises TableGen::Error do
      @gen.to_s
    end

    assert_equal 'insufficient width to generate the table', error.message
  end

  def test_stretch_outgrow
    @gen.width = 2
    @gen.row 'too long'

    @gen.column 0 do |col|
      col.stretch = true
    end

    error = assert_raises TableGen::Error do
      @gen.to_s
    end

    assert_equal 'insufficient width to generate the table', error.message
  end
end
