# frozen_string_literal: true

def bail(msg)
  puts msg
  exit 1
end

original_filename = ARGV[0]
bail 'Provide a file name' if original_filename.nil?

OBSIDIAN_ROOT = '/Users/andy/Dropbox/Obsidian/Personal/'
contenders = Dir.glob("#{OBSIDIAN_ROOT}**/#{original_filename}*.md")
bail 'No file found' if contenders.empty?
bail "Ambiguous file name. Found:\n#{contenders.join("\n")}\n" if contenders.size > 1

original_path = contenders.first
original_dir = File.dirname(original_path)
original_contents = File.read(original_path)
lines = original_contents.split("\n")
splits = lines.grep(/^- /)

original_contents.gsub!(/^- .+\n/, '') # Remove the splits
minute = original_contents.match(/^time: \d\d:(\d\d)/)[1].to_i

splits.each_with_index do |split, i|
  minute += 1
  new_path = File.join(original_dir, "#{original_filename}-#{i + 1}.md")
  split_contents = original_contents.sub(/(time: \d\d:)\d\d/, "\\1#{'%02d' % minute}")
                                    .sub(/Synopsis:: .+$/, split.sub(/^- /, 'Synopsis:: '))

  File.open(new_path, 'w') { |f| f.write split_contents }
  puts "new: #{new_path}"
end

File.open(original_path, 'w') { |f| f.write original_contents }
puts "mod: #{original_path}"
