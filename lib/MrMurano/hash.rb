# Last Modified: 2017.07.19 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'orderedhash'

class Hash
  # From:
  #   http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
  #
  # Take keys of hash and transform those to symbols.
  def self.transform_keys_to_symbols(value)
    return value.map { |v| Hash.transform_keys_to_symbols(v) } if value.is_a?(Array)
    return value if not value.is_a?(Hash)
    value.inject({}) { |memo, (k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo }
  end

  # From:
  #   http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
  #
  # Take keys of hash and transform those to strings.
  def self.transform_keys_to_strings(value)
    return value.map { |v| Hash.transform_keys_to_strings(v) } if value.is_a?(Array)
    return value if not value.is_a?(Hash)
    value.inject({}) { |memo, (k,v)| memo[k.to_s] = Hash.transform_keys_to_strings(v); memo }
  end

  # From Rails.
  def deep_merge!(other_hash, &block)
    other_hash.each_pair do |current_key, other_value|
      this_value = self[current_key]
      if this_value.is_a?(Hash) && other_value.is_a?(Hash)
        self[current_key] = this_value.deep_merge(other_value, &block)
      elsif block_given? && key?(current_key)
        self[current_key] = block.call(current_key, this_value, other_value)
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

