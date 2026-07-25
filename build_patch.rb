#!/usr/bin/env ruby
# Builds patch.zip + deletions.txt for GameUpdater by diffing two copies of
# the game folder (the previous released version vs. the new one).
#
# Usage:
#   ruby build_patch.rb <old_version_dir> <new_version_dir> [output_dir]
#
# Point old/new at two full copies of the game folder as they'd actually be
# distributed to players (i.e. however you already prepare a release). This
# tool doesn't know or assume anything about your release process beyond
# "diff these two folders" - it's your job to make sure both folders are in
# a state you'd actually want to ship.
#
# Output: <output_dir>/patch.zip (added/changed files) and, if anything was
# removed, <output_dir>/deletions.txt (one relative path per line). Upload
# both as assets to this repo's "latest" release afterwards.

require 'digest'
require 'fileutils'

$LOAD_PATH.unshift(File.join(__dir__, 'gems'))
require 'zip'

EXCLUDE_PATTERNS = [
  /(^|\/)\.git(\/|$)/,
  /(^|\/)\.DS_Store$/,
  /(^|\/)Thumbs\.db$/,
].freeze

def collect_files(root)
  files = {}
  Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each do |path|
    next if File.directory?(path)
    relative = path.delete_prefix(root).delete_prefix('/').delete_prefix('\\').gsub('\\', '/')
    next if EXCLUDE_PATTERNS.any? { |pattern| relative =~ pattern }
    files[relative] = path
  end
  files
end

old_dir = ARGV[0]
new_dir = ARGV[1]
output_dir = ARGV[2] || __dir__

if old_dir.nil? || new_dir.nil?
  abort "Usage: ruby build_patch.rb <old_version_dir> <new_version_dir> [output_dir]"
end
abort "Old version dir not found: #{old_dir}" unless Dir.exist?(old_dir)
abort "New version dir not found: #{new_dir}" unless Dir.exist?(new_dir)

old_dir = File.expand_path(old_dir)
new_dir = File.expand_path(new_dir)
FileUtils.mkdir_p(output_dir)

puts "Scanning old version (#{old_dir})..."
old_files = collect_files(old_dir)
puts "Scanning new version (#{new_dir})..."
new_files = collect_files(new_dir)

added_or_changed = []
new_files.each do |relative, full_path|
  old_full = old_files[relative]
  if old_full.nil? || Digest::SHA256.file(old_full).hexdigest != Digest::SHA256.file(full_path).hexdigest
    added_or_changed << relative
  end
end

deleted = old_files.keys.reject { |relative| new_files.key?(relative) }

puts "#{added_or_changed.size} file(s) added/changed"
puts "#{deleted.size} file(s) deleted"

if added_or_changed.empty? && deleted.empty?
  puts "No differences found - nothing to patch."
  exit
end

patch_path = File.join(output_dir, 'patch.zip')
FileUtils.rm_f(patch_path)
Zip::File.open(patch_path, create: true) do |zip|
  added_or_changed.each do |relative|
    zip.add(relative, new_files[relative])
  end
end
puts "Wrote #{patch_path}"

if deleted.any?
  deletions_path = File.join(output_dir, 'deletions.txt')
  File.write(deletions_path, deleted.join("\n") + "\n")
  puts "Wrote #{deletions_path}"
else
  puts "No deletions - skipping deletions.txt"
end

puts "\nDone. Upload patch.zip (and deletions.txt, if present) to the 'latest' release, and bump the version in the gist."
