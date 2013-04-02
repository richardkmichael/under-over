module Backup
  class Source

    attr_reader :path

    def initialize path
      @path = if path.length > 1 and path.end_with? '/'
                path[0..-2]
              else
                path
              end
    end

    def backup_paths
      backup_paths = []
      if File.exists? @path
        backup_paths << @path
        backup_paths.concat find_logrotations
      end

      backup_paths
    end

    private

    def find_logrotations
      rotations = []
      unless File.directory? @path

        ext = File.extname @path
        path_no_ext = @path.gsub /#{ext}$/, ''
        possible_backup_files = Dir.glob("#{path_no_ext}*")

        # Appended rotations or inserted, optional compression: system.log.1{.gz} or system.1.log{.gz}
        postfix_log_number = Regexp.new "#{@path}\.[0-9]+(\.gz)*$"
        infix_log_number   = Regexp.new "#{path_no_ext}\.[0-9]+#{ext}(\.gz)*$"
        log_rotations      = Regexp.union postfix_log_number, infix_log_number

        rotations.concat possible_backup_files.select { |f| f.match log_rotations }
      end

      rotations
    end
  end # Source
end # Backup
