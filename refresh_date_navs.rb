# frozen_string_literal: true

require_relative 'date_nav'

JOURNAL_PATH = '/Users/andy/Dropbox/Obsidian/Personal/journal'
UNWANTED_NAV = "```dataviewjs\nconst {DateNav} = customJS\nDateNav.nav(dv)\n```\n"

# List of paths
available_date_paths = Dir.glob("#{JOURNAL_PATH}/????-??-??.md").sort

# List of dates
available_dates = available_date_paths.map do |path|
  Date.parse(path)
rescue ArgumentError
  nil
end.compact

def save(lines, path)
  File.open(path, 'w') { |f| f.write lines.join }
  # puts "\n------> #{path}\n#{lines.join}"
end

# For each file
available_date_paths.each do |path|
  contents = File.read(path)
  cleaned_contents = contents.sub(UNWANTED_NAV, '')
  lines = cleaned_contents.split("\n").map { |line| "#{line}\n" }

  unless lines[0] =~ /^#/
    puts "#{path}: file does not start with a #, skipping"
    next
  end

  existing_nav = lines[1]&.chomp # Always 2nd line
  new_nav = DateNav.new(Date.parse(path), available_dates).write

  if existing_nav =~ /[<>≪≫]/
    if existing_nav == new_nav
      print '.'
    else
      print 'u'
      lines[1] = "#{new_nav}\n"
      save(lines, path)
    end
  else
    print 'i'
    lines[0] = "#{lines[0]}#{new_nav}\n\n"
    save(lines, path)
  end
end

puts
