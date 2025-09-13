# frozen_string_literal: true

require_relative 'date_nav'

JOURNAL_PATH = '/Users/andy/Dropbox/Obsidian/Personal/journal'

# List of paths
available_date_paths = Dir.glob("#{JOURNAL_PATH}/????-??-??.md").sort

# List of dates
available_dates = available_date_paths.map do |path|
  Date.parse(path)
rescue ArgumentError
  nil
end.compact

def save(contents, path)
  File.open(path, 'w') { |f| f.write contents }
  # puts "\n------> #{path}\n#{contents}"
end

# For each file
available_date_paths.each do |path|
  latest_nav = DateNav.new(Date.parse(path), available_dates).write
  contents = File.read(path)
  updated_contents = contents.sub(/^.*[≪≫].*$/, latest_nav)

  if contents == updated_contents
    print '.'
  else
    print 'u'
    save(updated_contents, path)
  end
end

puts
