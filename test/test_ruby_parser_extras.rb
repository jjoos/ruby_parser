# encoding: US-ASCII

require 'rubygems'
gem "minitest"
require 'minitest/autorun'
require 'ruby_parser_extras'

require 'minitest/unit'

class TestStackState < MiniTest::Unit::TestCase
  attr_reader :s

  def setup
    @s = RubyParserStuff::StackState.new :test
  end

  def assert_encoding str, default = false
    orig_str = str.dup
    p = Ruby19Parser.new
    s = nil

    out, err = capture_io do
      s = p.handle_encoding str
    end

    assert_equal orig_str.sub(/\357\273\277/, ''), s
    assert_equal "", out

    if defined?(Encoding) then
      assert_equal "", err
      assert_equal "UTF-8", s.encoding.to_s, str.inspect
    else
      if default then
        assert_equal "", err
      else
        assert_equal "Skipping magic encoding comment\n", err
      end
    end
  end

  def test_handle_encoding_bom
    # bom support, default to utf-8
    assert_encoding "\xEF\xBB\xBF# blah"
    # we force_encode to US-ASCII, then encode to UTF-8 so our lexer will work
    assert_encoding "\xEF\xBB\xBF# encoding: US-ASCII"
  end

  def test_handle_encoding_default
    assert_encoding "blah", :default
  end

  def test_handle_encoding_emacs
    assert_encoding "# -*- coding: UTF-8 -*-"
    assert_encoding "# -*- mode: ruby; coding: UTF-8 -*-"
    assert_encoding "# -*- mode: ruby; coding: UTF-8; blah: t -*-"
  end

  def test_handle_encoding_english_wtf
    assert_encoding "# Ruby 1.9: encoding: utf-8"
  end

  def test_handle_encoding_normal
    assert_encoding "# encoding: UTF-8"
    assert_encoding "# coding: UTF-8"
    assert_encoding "# encoding = UTF-8"
    assert_encoding "# coding = UTF-8"
  end

  def test_handle_encoding_vim
    assert_encoding "# vim: set fileencoding=utf-8"
  end

  def test_stack_state
    s.push true
    s.push false
    s.lexpop
    assert_equal [false, true], s.stack
  end

  def test_is_in_state
    assert_equal false, s.is_in_state
    s.push false
    assert_equal false, s.is_in_state
    s.push true
    assert_equal true, s.is_in_state
    s.push false
    assert_equal false, s.is_in_state
  end

  def test_lexpop
    assert_equal [false], s.stack
    s.push true
    s.push false
    assert_equal [false, true, false], s.stack
    s.lexpop
    assert_equal [false, true], s.stack
  end

  def test_pop
    assert_equal [false], s.stack
    s.push true
    assert_equal [false, true], s.stack
    assert_equal true, s.pop
    assert_equal [false], s.stack
  end

  def test_push
    assert_equal [false], s.stack
    s.push true
    s.push false
    assert_equal [false, true, false], s.stack
  end
end

class TestEnvironment < MiniTest::Unit::TestCase
  def deny t
    assert ! t
  end

  def setup
    @env = RubyParserStuff::Environment.new
    @env[:blah] = 42
    assert_equal 42, @env[:blah]
  end

  def test_use
    @env.use :blah
    expected = [{ :blah => true }]
    assert_equal expected, @env.instance_variable_get(:"@use")
  end

  def test_use_scoped
    @env.use :blah
    @env.extend
    expected = [{}, { :blah => true }]
    assert_equal expected, @env.instance_variable_get(:"@use")
  end

  def test_used_eh
    @env.extend :dynamic
    @env[:x] = :dvar
    @env.use :x
    assert_equal true, @env.used?(:x)
  end

  def test_used_eh_none
    assert_equal nil, @env.used?(:x)
  end

  def test_used_eh_scoped
    self.test_used_eh
    @env.extend :dynamic
    assert_equal true, @env.used?(:x)
  end

  def test_var_scope_dynamic
    @env.extend :dynamic
    assert_equal 42, @env[:blah]
    @env.unextend
    assert_equal 42, @env[:blah]
  end

  def test_var_scope_static
    @env.extend
    assert_equal nil, @env[:blah]
    @env.unextend
    assert_equal 42, @env[:blah]
  end

  def test_dynamic
    expected1 = {}
    expected2 = { :x => 42 }

    assert_equal expected1, @env.dynamic
    begin
      @env.extend :dynamic
      assert_equal expected1, @env.dynamic

      @env[:x] = 42
      assert_equal expected2, @env.dynamic

      begin
        @env.extend :dynamic
        assert_equal expected2, @env.dynamic
        @env.unextend
      end

      assert_equal expected2, @env.dynamic
      @env.unextend
    end
    assert_equal expected1, @env.dynamic
  end

  def test_all_dynamic
    expected = { :blah => 42 }

    @env.extend :dynamic
    assert_equal expected, @env.all
    @env.unextend
    assert_equal expected, @env.all
  end

  def test_all_static
    @env.extend
    expected = { }
    assert_equal expected, @env.all

    @env.unextend
    expected = { :blah => 42 }
    assert_equal expected, @env.all
  end

  def test_dynamic_eh
    assert_equal false, @env.dynamic?
    @env.extend :dynamic
    assert_equal true, @env.dynamic?
    @env.extend
    assert_equal false, @env.dynamic?
  end

  def test_all_static_deeper
    expected0 = { :blah => 42 }
    expected1 = { :blah => 42, :blah2 => 24 }
    expected2 = { :blah => 27 }

    @env.extend :dynamic
    @env[:blah2] = 24
    assert_equal expected1, @env.all

    @env.extend 
    @env[:blah] = 27
    assert_equal expected2, @env.all

    @env.unextend
    assert_equal expected1, @env.all

    @env.unextend
    assert_equal expected0, @env.all
  end
end
