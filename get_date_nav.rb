# frozen_string_literal: true

require_relative 'date_nav'

JOURNAL_PATH = '/Users/andy/Dropbox/Obsidian/Personal/journal'
available_date_filenames = Dir.entries(JOURNAL_PATH).sort

available_dates = available_date_filenames.map do |filename|
  Date.parse(filename)
rescue ArgumentError
  nil
end.compact

reference_date = if ARGV[0]
                   Date.parse(ARGV[0])
                 elsif ENV['date']
                   Date.parse(ENV['date'])
                 else
                   Date.today
                 end

puts DateNav.new(reference_date, available_dates).write
