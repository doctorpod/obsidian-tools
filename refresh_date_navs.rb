# frozen_string_literal: true

require_relative 'date_nav'

JOURNAL_PATH = '/Users/andy/Dropbox/Obsidian/Personal/journal'
available_date_paths = Dir.glob(JOURNAL_PATH + '/????-??-??.md').sort

available_dates = available_date_paths.map do |path|
  begin
    Date.parse(path)
  rescue ArgumentError
    nil
  end
end.compact

available_date_paths.last(400).each do |path|
  lines = File.readlines(path)

  unless lines[0] =~ /^#/
    puts "#{path}: file does not start with a #, skipping"
    next
  end

  existing_nav = lines[1].chomp # Always 2nd line
  new_nav = DateNav.new(Date.parse(path), available_dates).write

  if existing_nav =~ /[<>≪≫]/
    unless existing_nav == new_nav
      puts "#{path}: update nav"
      lines[1] = new_nav + "\n"
      File.open(path, 'w') { |f| f.write lines.join }
    end
  else
    puts "#{path}: insert nav"
    lines[0] = "#{lines[0]}#{new_nav}\n\n"
    File.open(path, 'w') { |f| f.write lines.join }
  end
end
