# frozen_string_literal: true

require 'date'

text = ARGV[0]
created_at = DateTime.parse ARGV[1]

filepath = "./keep_converter/#{created_at.strftime('%Y-%m-%d %H.%M.%S')}.md"
template = "---\ndate: #{created_at.strftime('%Y-%m-%d')}\ntime: #{created_at.strftime('%H:%M:%S')}\n---\nSynopsis:: #{text}\n\n-- [[#{created_at.strftime('%Y-%m-%d')}]]\n"

File.write(filepath, template)
