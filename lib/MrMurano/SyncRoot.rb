# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

module MrMurano
  ## Track what things are syncable.
  class SyncRoot
    include Singleton

    # A thing that is syncable.
    Syncable = Struct.new(:name, :class, :type, :desc, :bydefault) do
    end

    def initialize
      @syncset = []
    end

    ##
    # Return the @syncset
    # @return [Array<String>] array of Syncables
    attr_reader :syncset

    ##
    # Add a new entry to syncable things
    # @param name [String] The name to use for the long option
    # @param klass [Class] The class to instanciate from
    # @param type [String] Single letter for short option and status listing
    # @param desc [String] Summary of what this syncs.
    # @param bydefault [Boolean] Is this part of the default sync group
    #
    # @return [nil]
    def add(name, klass, type, bydefault)
      # 2017-06-20: Maybe possibly enforce unique name policy for --syncset options.
      #@syncset.each do |a|
      #  if a.name == name.to_s
      #    msg = %{WARNING: SyncRoot.add called more than once for name "#{a.name}"}
      #    $stderr.puts HighLine.color(msg, :yellow)
      #  end
      #end
      @syncset << Syncable.new(name.to_s, klass, type, klass.description, bydefault)
      nil
    end

    ##
    # Remove all syncables.
    def reset
      @syncset = []
    end

    ##
    # Get the list of default syncables.
    # @return [Array<String>] array of names
    def bydefault
      @syncset = [] unless defined?(@syncset)
      @syncset.select(&:bydefault).map(&:name)
    end

    ##
    # Iterate over all syncables
    # @param block code to run on each
    def each
      @syncset = [] unless defined?(@syncset)
      @syncset.each { |a| yield a.name, a.type, a.class, a.desc }
    end

    ##
    # Iterate over all syncables with option arguments.
    # @param block code to run on each
    def each_option
      @syncset = [] unless defined?(@syncset)
      @syncset.each { |a| yield "-#{a.type.downcase}", "--[no-]#{a.name}", a.desc }
    end

    ##
    # Iterate over just the selected syncables.
    # @param opt [Hash{Symbol=>Boolean}] Options hash of which to select from
    # @param block code to run on each
    def each_filtered(opt)
      @syncset = [] unless defined?(@syncset)
      check_same(opt)
      @syncset.each do |a|
        if opt[a.name.to_sym] || opt[a.type.to_sym]
          yield a.name, a.type, a.class, a.desc
        end
      end
    end

    ## Adjust options based on all or none
    # If none are selected, select the bydefault ones.
    #
    # @param opt [Hash{Symbol=>Boolean}] Options hash of which to select from
    #
    # @return [nil]
    def check_same(opt)
      @syncset = [] unless defined?(@syncset)
      if opt[:all]
        @syncset.each { |a| opt[a.name.to_sym] = true }
      else
        any = @syncset.select { |a| opt[a.name.to_sym] || opt[a.type.to_sym] }
        if any.empty?
          bydef = $cfg['sync.bydefault'].split
          @syncset.select { |a| bydef.include? a.name }.each { |a| opt[a.name.to_sym] = true }
        end
      end

      nil
    end
  end
end

