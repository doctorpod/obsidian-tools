module Obsidian
  ALL_GLOB = '**/*.md'.freeze

  class Vault
    attr_reader :path

    def initialize(path)
      @path = path
    end

    # @return Array of all notes as Obsidian::Note
    def notes
      @notes ||= Dir.glob(File.join(path, ALL_GLOB)).sort.map { |path| Note.new(path) }
    end

    # @param Block which must return true
    # @return Array of matching notes
    def search(&block)
      notes.select { |note| block.call(note) }
    end

    # @return Array of unique linked file names
    def outlinks
      @outlinks ||= notes.map(&:outlinks).flatten.uniq.sort
    end
  end
end