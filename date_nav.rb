# frozen_string_literal: true

require 'date'

class DateNav
  attr_reader :reference_date, :prev_available_dates, :next_available_dates

  def initialize(reference_date, sorted_available_dates)
    @reference_date = reference_date
    @prev_available_dates = sorted_available_dates.select { |d| d < reference_date }
    @next_available_dates = sorted_available_dates.select { |d| d > reference_date }
  end

  def write
    [
      prev_hits.map { |e| "[[#{e.last}|≪#{e.first}]]" }.join(' '),
      next_hits.map { |e| "[[#{e.last}|#{e.first}≫]]" }.join(' ')
    ].join(' | ').strip
  end

  MONTH_SEARCH_RADIUS = 3 # Was 10
  YEAR_SEARCH_RADIUS = 10 # Was 90

  def prev_hits
    [
      [:prev, prev_date],
      [:month, nearest(reference_date.prev_month, MONTH_SEARCH_RADIUS, prev_available_dates)],
      [:year, nearest(reference_date.prev_year, YEAR_SEARCH_RADIUS, prev_available_dates)]
    ].reject { |segment| segment.last.nil? } .reverse
  end

  def next_hits
    [
      [:next, next_date],
      [:month, nearest(reference_date.next_month, MONTH_SEARCH_RADIUS, next_available_dates)],
      [:year, nearest(reference_date.next_year, YEAR_SEARCH_RADIUS, next_available_dates)]
    ].reject { |segment| segment.last.nil? }
  end

  # Must be called first
  def prev_date
    prev_available_dates.pop
  end

  def next_date
    next_available_dates.shift
  end

  def nearest(target, search_radius, dates)
    (0..search_radius).to_a.each do |offset|
      new_target = target - offset
      return new_target if dates.include?(new_target)

      new_target = target + offset
      return new_target if dates.include?(new_target)
    end

    nil
  end
end
