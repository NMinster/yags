require File.dirname(__FILE__) + '/../test_helper'

class CookedBitGeneratorTest < Test::Unit::TestCase

  def test_random_bit
    bits = [0, 1, 0, 1, 0, 0, 1, 1]
    generator = CookedBitGenerator.new(bits)
    bits.each do |bit|
      assert_equal bit, generator.random_bit
    end
  end

  def test_random_bit_ignores_parameter
    bits = [0, 1, 0, 1, 0, 0, 1, 1]
    generator = CookedBitGenerator.new(bits)
    bits.each do |bit|
      assert_equal bit, generator.random_bit(0.14159)
    end
  end

  def test_random_bit_wraps
    bits = [0, 1, 1, 1, 0, 0, 1, 1]
    generator = CookedBitGenerator.new(bits)
    bits.each do |bit|
      assert_equal bit, generator.random_bit
    end
    bits.each do |bit|
      assert_equal bit, generator.random_bit
    end
    
    bits = [0]
    generator = CookedBitGenerator.new(bits)
    1.upto(1000) do |i|
      assert_equal 0, generator.random_bit
    end
  end
end