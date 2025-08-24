# frozen_string_literal: true

require 'byebug'
require_relative 'lib/obsidian'

# Stores replacement text
class Replacement
  def initialize
    @data = {}
  end

  def add(note_name, replacement_text)
    @data[note_name] ||= []
    @data[note_name] << replacement_text
  end

  def replacement_text(note_name)
    @data[note_name].join("\n")
  end

  def to_s
    @data.map { |note_name, _text| "\n#{note_name}:\n#{replacement_text(note_name)}" }
  end
end

VAULT_PATH = '/Users/andy/Dropbox/Obsidian/Personal'
LOG_PATH_REGEX = %r{/\d\d\d\d-\d\d-\d\d .+.md}.freeze
LOG_HISTORY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs\.historyAllWithContext\(dv\)\n```/.freeze
LOG_SUMMARY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs.headlineByYear\(dv\)\n```/.freeze
YEAR_SUMMARY_REGEX = /```dataviewjs\nconst {Logs} = customJS\nLogs\.headlineByMonth\(dv\)\n```/.freeze
CUSTOM_JS_REGEX = /```dataviewjs\nconst {[a-zA-Z]*} = customJS[^`]+```/m.freeze

vault = Obsidian::Vault.new(VAULT_PATH)
all_logs = vault.search { |n| n.path_like?(LOG_PATH_REGEX) }.map { |n| Obsidian::LogNote.new(n) }
all_outlinks = vault.outlinks

vault.search { |n| n.find(LOG_HISTORY_REGEX) }
vault.search { |n| n.find(LOG_SUMMARY_REGEX) }
yearly_summary_notes = vault.search { |n| n.find(YEAR_SUMMARY_REGEX) }

vault.search { |n| n.tag?('type/cultivation') }.map(&:path)

vault.search { |n| n.find(CUSTOM_JS_REGEX) }.map(&:hits).flatten.sort.uniq.each { |h| puts "---> #{h}" }

daily_replacements = Replacement.new
yearly_summary_replacements = Replacement.new

all_logs.each do |log|
  puts "\nLog: #{log.path} -- #{log.year} #{log.month_short} -- daily: #{log.daily_note_name}\n------"
  # puts 'Referenced!' if all_outlinks.include?(log.file_name)
  # puts "Outlinks: #{log.outlinks}"
  # puts "Properties: #{log.properties}"
  # puts "Tags: #{log.tags}"

  # Replace log history in outlinked files
  # Replace log summary in outlinked files

  # Replace yearly summary in outlinked year files
  referenced_yearlies = yearly_summary_notes.select { |n| log.outlinks.include?(n.file_name) }
  # puts "Yearlies: #{log.path}: #{referenced_yearlies}" if referenced_yearlies.any?

  referenced_yearlies.each do |yearly|
    yearly_summary_replacements.add(yearly.file_name, "- [[#{log.daily_note_name(ext: false)}|#{log.headline}]]")
  end

  # Merge log if no inlinks
  if log.inlinks?(all_outlinks)
    puts 'Log has inlinks, keep separate and link from daily'
    # puts "--> #{log.inlinks(vault.notes.map(&:file_name))}"
    daily_replacements.add(log.daily_note_name, "[[#{log.file_name}]]")
  else
    puts 'Log has no inlinks, merge it into the daily'
    daily_replacements.add(log.daily_note_name, log.sanitised_contents)
  end
end

# puts daily_replacements.to_s
puts yearly_summary_replacements.to_s
