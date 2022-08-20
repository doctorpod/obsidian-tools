# frozen_string_literal: true

require 'date'

JOURNAL_PATH = '/Users/andy/Dropbox/Obsidian/Personal/journal'
available_date_filenames = Dir.entries(JOURNAL_PATH).sort

available_dates = available_date_filenames.map do |filename|
  begin
    Date.parse(filename)
  rescue ArgumentError
    nil
  end
end.compact

def find_nearest(available, ref, direction = :both, offset = 100)
  return ref if available.include?(ref)

  (1..offset).to_a.each do |offset|
    if %i[back both].include?(direction)
      proposed = ref.prev_day(offset)
      return proposed if available.include?(proposed)
    end

    if %i[fwd both].include?(direction)
      proposed = ref.next_day(offset)
      return proposed if available.include?(proposed)
    end
  end

  nil
end

reference_date = if ARGV[0]
                   Date.parse(ARGV[0])
                 elsif ENV['date']
                   Date.parse(ENV['date'])
                 else
                   Date.today
                 end

left = {
  year: find_nearest(available_dates, reference_date.prev_year, :both, 100),
  month: find_nearest(available_dates, reference_date.prev_month, :both, 15),
  week: find_nearest(available_dates, reference_date.prev_day(7), :back, 3),
  prev: find_nearest(available_dates, reference_date.prev_day, :back, 1)
}.reject { |_k, v| v.nil? }.map { |label, date| "[[#{date}|≪#{label}]]" }.join(' ')

right = {
  next: find_nearest(available_dates, reference_date.next_day, :fwd, 1),
  week: find_nearest(available_dates, reference_date.next_day(7), :fwd, 3),
  month: find_nearest(available_dates, reference_date.next_month, :both, 15),
  year: find_nearest(available_dates, reference_date.next_year, :both, 100)
}.reject { |_k, v| v.nil? }.map { |label, date| "[[#{date}|#{label}≫]]" }.join(' ')

puts "#{left} | #{right}"
