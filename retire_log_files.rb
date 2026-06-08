# frozen_string_literal: true

require 'date'

# Stores replacement date and text for each path
#
class Replacements
  attr_reader :data

  def initialize
    @data = {}
  end

  def add_daily(path, synopsis, remaining_content)
    @data[path] ||= {}
    @data[path][:daily] ||= []
    @data[path][:daily] << {synopsis: synopsis, remaining_content: remaining_content}
  end

  def add_summary(path, date_string, headline)
    @data[path] ||= {}
    @data[path][:summary] ||= []
    @data[path][:summary] << {date: Date.parse(date_string), date_string: date_string, headline: headline}
  end

  def replacement_daily(path)
    data = @data[path][:daily]

    data.map { |d| "#{d[:synopsis]}\n#{d[:remaining_content]}" } .join("\n")
  end

  def replacement_summary(path, level = 2)
    data = @data[path][:summary]
    tree = {}

    data.each do |entry|
      year = entry[:date].year
      month = entry[:date].strftime('%b')

      tree[year] ||= {}
      tree[year][month] ||= []
      tree[year][month] << "- [[#{entry[:date_string]}|#{entry[:headline]}]]"
    end

    tree.map do |year, months|
      month_strings = months.map do |month, entries|
        "##{'#' * level} #{month}\n#{entries.join("\n")}"
      end.join("\n")

      "\n#{'#' * level} #{year}\n#{month_strings}"
    end.join.lstrip
  end

  # For debugging
  def print
    @data.each do |path, replacements|
      puts "\n\nReplacements for #{path}:"
      replacements.each do |type, _entries|
        puts " -- #{type}:"
        puts replacement_daily(path) if type == :daily
        puts replacement_summary(path) if type == :summary
      end
    end
  end
end

the_replacements = Replacements.new

# Deals with both frontmatter 'property: value' and inline 'Property:: value' formats
#
# @param property String - property name to match, e.g. 'headline' or 'synopsis'
# @param capture_number Integer - which capture group to return, e.g. 1 for the value after 'headline:'
# @param string String - the string to search for the property
# @return String of the matched property value, or nil if not found
def get_value(property, string)
  match = string.match(/^#{property}:(.+$)/) || string.match(/^#{property.capitalize}::(.+$)/)
  match ? match[1].strip : nil
end

# @param content String - the content of a log file
# @return Array of unique linked file names in the content, with links stripped of display text
# and block references
def linked_files(content)
  content.scan(LINK_TEXT_REGEX).map do |raw_link|
    raw_link.sub('[[','').sub(']]','').sub(/\|.+$/,'').sub(/#.+$/,'')
  end.uniq
end

VAULT_PATH = ENV['NOTESP'].freeze

FRONT_MATTER_REGEX = /\A---\n(.+?)\n---/m.freeze
LOG_PATH_REGEX = %r{/\d\d\d\d-\d\d-\d\d .+.md}.freeze
LINK_TEXT_REGEX = /\[\[[^\[\]]+\]\]/.freeze

# These regexes are used to identify the type of Dataview powered summarisations used in non-log files
LOG_DAILY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs\.historyDayByContext\(dv\)\n```/.freeze
LOG_HISTORY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs\.historyAllWithContext\(dv\)\n```/.freeze
LOG_SUMMARY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs.headlineByYear\(dv\)\n```/.freeze
YEAR_SUMMARY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs\.headlineByMonth\(dv\)\n```/.freeze

# A catch-all regex
CUSTOM_JS_REGEX = /```dataviewjs\nconst {[a-zA-Z]*} = customJS[^`]+```/m.freeze

all_files = Dir.glob(File.join(VAULT_PATH, '**', '*.md')).sort
log_files = all_files.select { |f| f =~ LOG_PATH_REGEX }

indexed_files = all_files.to_h do |path|
  [
    File.basename(path, '.md'), # file name without extension
    path # full path
  ]
end

log_files.each do |log_path|
  content = File.read(log_path)
  
  # Get log file property and body values
  date_string = get_value('date', content)
  headline = get_value('headline', content)
  context = get_value('context', content)
  synopsis = get_value('synopsis', content)
  remaining_content = content.gsub(FRONT_MATTER_REGEX, '')
                             .gsub(/^Synopsis::.+$/, '')
                             .gsub(/^Headline::.+$/, '')
                             .gsub(/^Context::.+$/, '')
                             .gsub(/\[\[\d\d\d\d-\d\d-\d\d\]\],?\s*/, '') # remove links to the daily
                             .gsub(/^--[\s,]+$/, '') # remove related dashes if empty
                             .strip

  outlinked_files = linked_files(content)

  unless synopsis
    STDERR.puts "Warning: no synopsis found for log file '#{log_path}', skipping"
    next
  end 

  outlinked_files.each do |file_name|
    linked_path = indexed_files[file_name]

    unless linked_path      
      STDERR.puts "Warning: linked file '#{file_name}' not found in vault, skipping"
      next
    end

    linked_content = File.read(linked_path)
    
    if linked_content =~ LOG_DAILY_REGEX
      the_replacements.add_daily(linked_path, synopsis, remaining_content)
    end

    if linked_content =~ LOG_HISTORY_REGEX
      # We're probably going to get rid of these in favour of the summary logs
    end

    if linked_content =~ LOG_SUMMARY_REGEX || linked_content =~ YEAR_SUMMARY_REGEX
      unless headline
        STDERR.puts "Warning: no headline found for log file '#{log_path}', skipping summary entry for #{file_name}"
        next
      end

      the_replacements.add_summary(linked_path, date_string, headline)
    end
  end
end

# Substitute DataviewJS log summaries with the generated replacement text, 
# e.g. for daily logs, history logs, etc.
the_replacements.data.each do |path, replacements|
  if File.exist?(path)
    content = File.read(path)

    replacements.each do |type, _entries|
      content.gsub!(LOG_DAILY_REGEX, the_replacements.replacement_daily(path)) if type == :daily
      content.gsub!(LOG_SUMMARY_REGEX, the_replacements.replacement_summary(path, 2)) if type == :summary
      content.gsub!(YEAR_SUMMARY_REGEX, the_replacements.replacement_summary(path, 1)) if type == :summary
    end

    File.write(path, content)
    puts "\n\nUpdated content for #{path}\n------------\n#{content}"
  else
    STDERR.puts "Warning: file '#{path}' not found for replacement, skipping"
  end
end

# Delete log files
log_files.each { |path| File.delete(path) }
