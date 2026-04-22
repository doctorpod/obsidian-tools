# frozen_string_literal: true

# Stores replacement date and text for each path
#
# @data looks like:
# {
#   'Daily/2024-01-01.md' => [
#     [(Date), '- whatever, [[a link]], blah'],
#     [(Date), 'bish bosh bash, [[another link]], blah']
#   ],
#   'Yearly/2024.md' => [
#     ... etc
#   ]
# }
class Replacements
  def initialize
    @data = {}
  end

  # @param path String - file name to add replacement for
  # @param date String - date of the replacement, used for sorting, month etc
  # @param replacement_text String - text to replace with
  def add(path, date, replacement_text)
    @data[path] ||= []
    @data[path] << [Date.parse(date), replacement_text]
  end

  # FIXME: This is currently just joining all the replacement text together, 
  # but we may want to have more specific formatting, e.g. separate by date
  #
  # @return String of replacement text for a given note name, with entries sorted by date
  def replacement_text(path)
    @data[path].sort_by { |(date, _text)| date }.map { |(_date, text)| text }.join("\n")
  end

  def log_history(path)
  end

  def log_summary(path)
  end

  def year_summary(path)
  end

  # For debugging
  def to_s
    @data.map { |path, date_and_text| "\n#{path}:\n#{replacement_text(path)}" }
  end
end

replacements = {}

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

  # puts "\nProcessing log: #{log_path}\n -- date: #{date_string}\n -- headline: #{headline}\n" \
  #      " -- context: #{context}\n -- synopsis: #{synopsis}\n -- remain: #{remaining_content}\n" \
  #      " -- links: #{outlinked_files.join("\n ------- ")}\n\n"

  outlinked_files.each do |file_name|
    linked_path = indexed_files[file_name]

    unless linked_path      
      STDERR.puts "Warning: linked file '#{file_name}' not found in vault, skipping"
      next
    end

    linked_content = File.read(linked_path)
    
    if linked_content =~ LOG_DAILY_REGEX
      # puts "Found daily log for #{file_name}"

      replacements[linked_path] ||= {}
      replacements[linked_path][:daily] ||= []
      replacements[linked_path][:daily] << synopsis + "\n" + remaining_content
    end

    if linked_content =~ LOG_HISTORY_REGEX
      # puts "Found history log for #{file_name}"

      replacements[linked_path] ||= {}
      # We're probably going to get rid of these in favour of the summary logs
      replacements[linked_path][:history] ||= []
    end

    if linked_content =~ LOG_SUMMARY_REGEX
      # puts "Found summary log for #{file_name}"

      unless headline
        STDERR.puts "Warning: no headline found for log file '#{log_path}', skipping summary entry for #{file_name}"
        next
      end

      replacements[linked_path] ||= {}
      replacements[linked_path][:summary] ||= []
      replacements[linked_path][:summary] << "- [[#{date_string}|#{headline}]]"
    end

    if linked_content =~ YEAR_SUMMARY_REGEX
      # puts "Found yearly log for #{file_name}"

      unless headline
        STDERR.puts "Warning: no headline found for log file '#{log_path}', skipping yearly entry for #{file_name}"
        next
      end

      replacements[linked_path] ||= {}
      replacements[linked_path][:yearly] ||= []
      replacements[linked_path][:yearly] << "- [[#{date_string}|#{headline}]]"
    end
  end
 
  # delete log file
end

# Substitute DataviewJS log summaries with the generated replacement text, 
# e.g. for daily logs, history logs, etc.

pp replacements

