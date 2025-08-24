# frozen_string_literal: true

module Obsidian
  class Link
    LINK_TEXT_REGEX = /\[\[([^#|]+)(#[^|]+)?(\|.+)?\]\]/.freeze

    attr_accessor :text, :source_note, :block_ref, :link_display, :referenced_note

    def initialize(text, source_note, all_notes)
      @text = text
      @source_note = source_note

      parts = text.scan(LINK_TEXT_REGEX).flatten
      note_name = parts[0]
      @block_ref = parts[1]
      @link_display = parts[2]

      @referenced_note = all_notes.find { |n| n.file_name == note_name }
      @referenced_note.inlinks << self
    end
  end
end
