require 'fileutils'
require './lib/backup_source.rb'

module Backup

  class SourceTypeError   < StandardError ; end
  class OutputExistsError < StandardError ; end

  class Controller

    DESTINATIONS = { :database => 'database-logs',
                     :system   => 'system-logs',
                     :web      => 'web-logs' }

    class << self
      # Reader initializes.  Seems like an instance is needed?  Then it would be done using #initialize().
      attr_writer   :sources, :staging_dirname, :output_filename
      def sources         ; @sources ||= []                      ; end
      def staging_dirname ; @staging_dirname ||= '/tmp/logs'     ; end
      def output_filename ; @output_filename ||= '/tmp/logs.tgz' ; end
    end

    # TODO: Change accessors to force use of ::configure with a block?
    def self.configure &config
      yield self
    end

    def self.reset
      self.output_filename = '/tmp/logs.tgz'
      self.staging_dirname = '/tmp/logs'
      self.sources = []
    end

    def self.add *new_sources
      sources.concat new_sources.map { |source| Source.new File.expand_path(source) }
    end

    def self.backup_sources
      sources.map { |source| source.path }.flatten
    end

    def self.backup_files
      sources.map { |source| source.backup_paths }.flatten
    end

    def self.backup
      with_staged_sources sources do
        write_tar_file
      end
    end

    private

    def self.with_staged_sources sources

      sources_with_content = sources.select { |source| File.exists? source.path }

      if sources_with_content.any?
        FileUtils.mkdir_p self.staging_dirname unless File.directory? self.staging_dirname
        sources_with_content.each { |source| stage source }
        yield
        sources_with_content.each { |source| unstage source }
        FileUtils.rmdir self.staging_dirname
      else
        puts 'INFO: No content to write.  Check your sources?'
      end
    end

    def self.write_tar_file
      if File.exist? self.output_filename
        raise OutputExistsError, "FATAL: Output file exists, refusing to clobber: #{self.output_filename}"
      else
        change, source = File.split self.staging_dirname

        tar = "/usr/bin/env tar --create --gzip --file #{self.output_filename} --dereference --directory #{change} #{source}"

        if system tar
          puts "INFO: Backup written to #{self.output_filename}."
          FileUtils.chmod 0700, self.output_filename # Protect the backup file.
        else
          puts "FATAL: tar failed with exit status: $?"
          FileUtils.rm self.output_filename
        end
      end
    end

    # I experimented with various solutions here.  One was making this a
    # concern of the BackupSource, such as a "source type" (e.g.
    # BackupSource#database_file?), or BackupSource#backup_files outputting
    # pairs.
    #
    # However, it seems like a Controller concern; for example, we don't want
    # to change the BackupSource class if the Controller decides to copy
    # instead of symlink.  Once a Controller concern, I considered a Hash of
    # destinations, but computing a destination in a general way is not
    # straight forward.  For example, if a BackupSource#backup_paths contains
    # multiple directories (it should not), we can't use a single destination
    # directory for the source.
    #
    # Therefore, for now, implement exactly the questions requirements with a
    # fragile and literal detection.  We don't expect to see any files which
    # are not immediate children of /var/log; and we only expect to see
    # directories /var/log/{mysql,nginx}.
    #
    def self.stage source
      destination = compute_destination source.path

      if File.file? source.path
      # require 'pry' ; binding.pry

        # If source is a file, create the "destination" directory and batch
        # link all associated files inside "destination".

        FileUtils.mkdir destination unless File.directory? destination
        FileUtils.ln_s source.backup_paths, destination

      else
        # If source is a directory, link only the directory; it will be renamed
        # to "destination".

        FileUtils.ln_s source.path, destination
      end
    end

    def self.unstage source
      destination = compute_destination source.path
      FileUtils.rm_rf destination
    end

    def self.compute_destination source_path
      dirname, basename = File.split source_path

      destination = if File.file? source_path
                      'system-logs'
                    elsif File.directory? source_path
                      case source_path
                      when /nginx$/
                        'web-logs'
                      when /mysql$/
                        'database-logs'
                      end
                    else
                      raise SourceTypeError, "FATAL: Unrecognized backup source: #{source_path}."
                    end

      File.join self.staging_dirname, destination
    end

  end # Controller
end # Backup
