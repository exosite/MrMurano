# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/verbosing'

module MrMurano
  ## The functionality of a Syncable thing.
  #
  # This provides the logic for computing what things have changed, and pushing and
  # pulling those things.
  #
  module SyncUpDown
    # This is one item that can be synced.
    class Item
      # @return [String] The name of this item.
      attr_accessor :name
      # @return [Pathname] Where this item lives.
      attr_accessor :local_path
      # FIXME/EXPLAIN: ??? what is this?
      attr_accessor :id
      # @return [String] The Lua code for this item. (not all items use this.)
      attr_accessor :script
      # @return [Integer] The line in #local_path where this #script starts.
      attr_accessor :line
      # @return [Integer] The line in #local_path where this #script ends.
      attr_accessor :line_end
      # @return [String] If requested, the diff output.
      attr_accessor :diff
      # @return [Boolean] When filtering, did this item pass.
      attr_accessor :selected
      # @return [String] The constructed name used to match local items to remote items.
      attr_accessor :synckey
      # @return [String] The syncable type.
      attr_accessor :synctype
      # @return [String] The updated_at time from the server is used to detect changes.
      attr_accessor :updated_at
      # @return [Integer] Positive if multiple conflicting files found for same item.
      attr_accessor :dup_count

      # Initialize a new Item with a few, or all, attributes.
      # @param hsh [Hash{Symbol=>Object}, Item] Initial values
      #
      # @example Initializing with a Hash
      #  Item.new(:name=>'Bob', :local_path => Pathname.new(…))
      # @example Initializing with an Item
      #  item = Item.new(:name => 'get')
      #  Item.new(item)
      def initialize(hsh={})
        hsh.each_pair { |k, v| self[k] = v }
      end

      def as_inst(key)
        return key if key.to_s[0] == '@'
        "@#{key}"
      end
      private :as_inst

      def as_sym(key)
        return key.to_sym if key.to_s[0] != '@'
        key.to_s[1..-1].to_sym
      end
      private :as_sym

      # Get attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @return [Object] The value
      def [](key)
        public_send(key.to_sym)
      rescue NoMethodError
        nil
      end

      # Set attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @param value [Object] value to set
      def []=(key, value)
        public_send("#{key}=", value)
      rescue StandardError => err
        MrMurano::Verbose.error(
          "Unable to set key: #{key} / value: #{value} / err: #{err} / self: #{inspect}"
        )
      end

      # Delete a key
      # @param key [String,Symbol] attribute name
      # @return [Object] The value
      def delete(key)
        inst = as_inst(key)
        remove_instance_variable(inst) if instance_variable_defined?(inst)
      end

      # @return [Hash{Symbol=>Object}] A hash that represents this Item
      def to_h
        Hash[instance_variables.map { |k| [as_sym(k), instance_variable_get(k)] }]
      end

      # Adds the contents of item to self.
      # @param item [Item,Hash] Stuff to merge
      # @return [Item] ourself
      def merge!(item)
        item.each_pair { |k, v| self[k] = v }
        self
      end

      # A new Item containing our plus items.
      # @param item [Item,Hash] Stuff to merge
      # @return [Item] New item with contents of both
      def merge(item)
        dup.merge!(item)
      end

      # Calls block once for each non-nil key
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @return [Item]
      def each_pair
        instance_variables.each do |key|
          yield as_sym(key), instance_variable_get(key)
        end
        self
      end

      # Delete items in self that block returns true.
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @yieldreturn [Boolean] True to delete this key
      # @return [Item] Ourself.
      def reject!(&_block)
        instance_variables.each do |key|
          drop = yield as_sym(key), instance_variable_get(key)
          delete(key) if drop
        end
        self
      end

      # A new Item with keys deleted where block is true
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @yieldreturn [Boolean] True to delete this key
      # @return [Item] New Item with keys deleted
      def reject(&block)
        dup.reject!(&block)
      end

      # For unit testing.
      include Comparable
      def <=>(other)
        # rubocop:disable Style/RedundantSelf: Redundant self detected.
        #   MAYBE/2017-07-18: Permanently disable Style/RedundantSelf?
        self.to_h <=> other.to_h
      end
    end
  end
end

