#!/usr/bin/env ruby

# TODO: compute_logrotate_pattern does not consider log files with a suffix preservation other than ".log".
# TODO: Ideally, use the logrotate gem to interrogate logrotate configuration.
# TODO: Tar path is *slightly* portable via 'env', horrible.
# TODO: Assumes gnutar, OK, we're ubuntu.
# TODO: Copying the files first is painful, what if they're big? Use links.
# TODO: Check normal file, not pipe, etc.
# TODO: Staging to a tempdir would be better; even better: no staging at all.
# TODO: rm_rf on the staging dir kind of sucks.
# TODO: Assumes rotated logs are stored in the same directory as the original log.
# TODO: The backup file will always be named after the staging dir and located right beside it. Ugh.

require 'fileutils'

def build_file_list sources
  sources = sources.map { |source| sanity_check source }.compact
  sources += find_logrotate_files sources
end

# Outputs a warning and returns nil if source fails sanity checks.
def sanity_check source
  if File.exists? source
    source
  else
    puts "Warning: #{source} does not exist, skipping."
  end
end

def find_logrotate_files sources
  logrotated_files = sources.map do |source|
    if File.file? source
      # If it's plain file, find it's rotated files.
      # Use select/regex because Dir.globs are not very helpful, e.g. no "\d+".
      logrotate_regex = compute_logrotate_regex source
      source_directory = File.dirname source
      Dir.glob("#{source_directory}/*").select { |filename| filename =~ logrotate_regex }
    else
      # A directory will include the logrotated files, nothing extra to add.
      nil
    end
  end
  logrotated_files.compact.flatten
end

def compute_logrotate_regex source
  filename = File.basename source
  if filename.end_with? '.log'
    # auth.log.1 OR auth.1.log, if the logrotate configuration uses 'extension log', for example.
    /#{filename[0..-5]}\.(\d+\.log|log\.\d+)/
  else
    # No suffix: syslog.1
    /#{filename}\.\d+/
  end
end

def stage_files sources

  FileUtils.rm_rf @stage_dir #TODO: Fix permissions: 700

  # HACK: We want to copy into the system-logs directory, so create it along with the stage_dir.
  FileUtils.mkdir_p(@stage_dir + '/system-logs')

  sources.each do |source|
    # When copying a known directory, use copy in a "renaming style".
    case source
    when '/var/log/mysql'
      FileUtils.cp_r source, @stage_dir + '/database-logs'
    when '/var/log/nginx'
      FileUtils.cp_r source, @stage_dir + '/web-logs'
    else
      FileUtils.cp_r source, @stage_dir + '/system-logs'
    end
  end
end

def write_backup_file
  output_file = @stage_dir + '.tgz'
  if File.exist? output_file
    raise "FATAL: Output file exists, refusing to clobber: #{output_file}"
  else
    change_to = File.dirname @stage_dir
    source = File.basename @stage_dir
    %x( /usr/bin/env tar --create --gzip --file #{output_file} --directory #{change_to} #{source} )
    #TODO: Fix permissions.
  end
end

def cleanup
  # Ensure this, even though the stage_files method does it too.
  FileUtils.rm_rf @stage_dir
end

# ========== MAIN ================

# For convenience use an ivar; ugly, but it's a script.
@stage_dir = '/tmp/logs'

sources = %w( /var/log/auth.log
              /var/log/dmesg
              /var/log/syslog
              /var/log/mysql
              /var/log/nginx )

files_to_backup = build_file_list(sources)

stage_files(files_to_backup)

write_backup_file

cleanup
