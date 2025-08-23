module Obsidian
  LINK_REGEX = /\[\[([a-zA-Z0-9\-.()&| ]*)\]\]/.freeze
  PROPERTY_REGEX = /^([a-zA-Z0-9\-.]*)::?(.*)$/.freeze
  TAG_REGEX = %r{#([a-zA-Z0-9\-._/]*)}.freeze

  class Note
    attr_reader :path, :hits
    attr_accessor :inlinks

    def initialize(path)
      @path = path
      @inlinks = []
    end

    def file_name
      File.basename(path, '.md')
    end

    def contents
      @contents ||= File.read(path)
    end

    # @return Array of unique linked file names
    def outlinks
      @outlinks ||= contents.scan(LINK_REGEX).flatten.map { |l| l.sub(/\|.*$/, '') }.uniq
    end

    # @return Boolean, true if any other notes link in
    def inlinks?(vault_outlinks)
      vault_outlinks.include?(file_name)
    end

    # @return Array of file names inlinking
    # def inlinks(vault_notes)
    #   @inlinks ||= vault_notes.select { |n| n.outlinks.include?(file_name) }.map(&:file_name)
    # end

    # @return Hash of property name (key), property value (value)
    def properties
      @properties ||= contents.scan(PROPERTY_REGEX).to_h.each { |_k, v| v.strip! }
    end

    # @return Array of tag names excluding the hash sign
    def tags
      @tags ||= contents.scan(TAG_REGEX).flatten
    end

    def tag?(name)
      tags.include?(name)
    end

    def path_like?(regex)
      path =~ regex ? true : false
    end

    # @return true if match found
    # store any hits
    def find(regex)
      @hits = contents.scan(regex)
      @hits.any?
    end
  end
end