# frozen_string_literal: true

date_str = ARGV[0]

OBSIDIAN_ROOT = '/Users/andy/Dropbox/Obsidian/Personal/'
JOURNAL_PATH = OBSIDIAN_ROOT + 'journal/'
path = JOURNAL_PATH + date_str + '.md'
log_times = %w[09:00 10:00 11:00 12:00 13:00 14:00 15:00 16:00 17:00 18:00 19:00 20:00 21:00 22:00 23:00]

content = File.read(path)
heading = content.split("\n").first
chunks = content.split("\n\n")
chunks.shift # Loose the title & old date nav

raise 'Not enough log times' if chunks.size > log_times.size

new_journal_contents = "#{heading}
```dataviewjs
const {DateNav} = customJS
DateNav.nav(dv)
```
```dataviewjs
const {Images, Logs} = customJS
Images.tile(dv, Logs.getAll(dv, 'images'))
```
```dataviewjs
const {Logs} = customJS
Logs.historyDayByContext(dv)
```
"

written = []
chunks.each_with_index do |line, i|
  log_time = log_times[i]
  log_year = date_str[0,4]
  log_path = "#{OBSIDIAN_ROOT}lib/#{log_year}/#{date_str} #{log_time.tr(':','.')}.00.md"
  log_contents = "---
date: #{date_str}
time: #{log_time}
---
Synopsis:: #{line}

-- [[#{date_str}]]"

  File.open(log_path, 'w') { |f| f.write log_contents }
  written << log_path
end

File.open(path, 'w') { |f| f.write new_journal_contents }
written << path

puts "Written:\n#{written.join("\n")}"