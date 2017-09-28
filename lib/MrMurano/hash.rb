# Last Modified: 2017.09.27 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/orderedhash'

class Hash
  # From:
  #   http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
  #
  # Take keys of hash and transform those to symbols.
  def self.transform_keys_to_symbols(value)
    return value.map { |v| Hash.transform_keys_to_symbols(v) } if value.is_a?(Array)
    return value unless value.is_a?(Hash)
    value.inject({}) { |memo, (k, v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo }
  end

  # From:
  #   http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
  #
  # Take keys of hash and transform those to strings.
  def self.transform_keys_to_strings(value)
    return value.map { |v| Hash.transform_keys_to_strings(v) } if value.is_a?(Array)
    return value unless value.is_a?(Hash)
    value.inject({}) { |memo, (k, v)| memo[k.to_s] = Hash.transform_keys_to_strings(v); memo }
  end

  # From Rails.
  def deep_merge!(other_hash, &block)
    other_hash.each_pair do |current_key, other_value|
      this_value = self[current_key]
      if this_value.is_a?(Hash) && other_value.is_a?(Hash)
        self[current_key] = this_value.deep_merge(other_value, &block)
      elsif block_given? && key?(current_key)
        self[current_key] = yield(current_key, this_value, other_value)
      else
        self[current_key] = other_value
      end
    end
    self
  end
end

def ordered_hash(dict)
  ohash = OrderedHash.new
  dict.keys.sort.each do |key|
    value = dict[key]
    if value.is_a? Hash
      ohash[key] = ordered_hash(value)
    else
      ohash[key] = value
    end
  end
  ohash
end

##
# Take a hash or something (a Commander::Command::Options) and return a hash
#
# @param hsh [Hash, Commander::Command::Options] Thing we want to be a Hash
# @return [Hash] an actual Hash with default value of false
def elevate_hash(hsh)
  # Commander::Command::Options stripped all of the methods from parent
  # objects. I have not nice thoughts about that.
  begin
    hsh = hsh.__hash__
  # rubocop:disable Lint/HandleExceptions: Do not suppress exceptions.
  rescue NoMethodError
    # swallow this.
  end
  # build a hash where the default is 'false' instead of 'nil'
  Hash.new(false).merge(Hash.transform_keys_to_symbols(hsh))
  # 2017-09-07: Note that after elevate_hash, the Hash returns
  #   false on unknown keys. This is because of the parameter to
  #   new: Hash.new(false). Unknown keys would return nil before,
  #   but after, they return false. E.g.,
  #
  #   (byeebug) options
  #   {:delete=>false, :create=>true, :update=>false}
  #   (byeebug) options[:fff]
  #   false
  #   (byeebug) options[:fff] = nil
  #   nil
  #   (byeebug) options[:fff]
  #   nil
  #   (byeebug) options[:fffd]
  #   false
  #   (byeebug) options
  #   {:delete=>false, :create=>true, :update=>false, :fff=>nil}
end

##
# Array-ify the given item, if not already an array.
#
# NOTE/2017-08-15: This fcn. is not hash-related, but this file is the
#   closest we've got to a generic utility method dumping ground.
def ensure_array(item)
  if item.nil?
    []
  elsif !item.is_a?(Array)
    [item]
  else
    item
  end
end

module HashInit
  def initialize(*hash)
    return unless hash.length == 1 && hash.first.is_a?(Hash)
    hash.first.each do |key, val|
      if respond_to? key
        send("#{key}=", val)
      elsif defined?(@show_errors) && @show_errors
        $stderr.puts %(HashInit: missing hash key "#{key}")
      end
    end
  end
end

