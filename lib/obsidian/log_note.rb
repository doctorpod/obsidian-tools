# frozen_string_literal: true

require 'delegate'
require 'date'

module Obsidian
  # Wrapper for Note which adds functionality
  class LogNote < SimpleDelegator
    FRONT_MATTER_REGEX = /^---.+---$/m.freeze
    TRAILING_DASHES_REGEX = /\s*\n\n--/.freeze

    def initialize(note)
      super
      @note = note
    end

    def daily_note_name(ext: true)
      basename = date.strftime('%Y-%m-%d')
      ext ? "#{basename}.md" : basename
    end

    def year
      date.year
    end

    def month_short
      date.strftime('%b')
    end

    def date
      Date.parse(@note.properties['date']) if @note.properties.include?('date')
    rescue Date::Error
      warn "Log: #{@note.path} has unparsable date: #{@note.properties['date']}"
      raise
    end

    def time
      @note.properties['time']
    end

    def headline
      @note.properties['Headline']
    end

    def sanitised_contents
      contents.sub(FRONT_MATTER_REGEX, '')
              # Remove unwanted property labels
              .sub(/^Synopsis:: /, '')
              .sub(/^Context:: /, '')
              .sub(/^Headline:: .+\n/, '')
              # Remove link to parent daily
              .sub(/\[\[#{date.strftime('%Y-%m-%d')}\]\],?/, '')
              # Remove any link to year
              .sub(/\[\[\d\d\d\d\]\],?/, '')
              # Tidy trailng double dashes
              .sub(TRAILING_DASHES_REGEX, ' --')
              .sub(/ --\s*$/, '')
              .sub(/ --\s+/, ' -- ')
    end
  end
end
