require './test/test_helper.rb'
require './lib/backup_source.rb'

module Backup
  class SourceTest < Test::Unit::TestCase

    def test_trailing_slash_is_handled_intelligently
      assert_equal 'test', Source.new('test/').path
      assert_equal '/', Source.new('/').path
    end

    def test_backup_paths_depends_on_existence
      source = Source.new test_filename('system.log')

      assert_empty source.backup_paths

      test_with_files %w( system.log ) do |test_files|
        assert_equal test_files, source.backup_paths
      end
    end

    def test_backup_paths_includes_logrotation
      source = Source.new test_filename('system.log')

      test_with_files %w( system.2.log system.log system.log.1 ) do |test_files|
        assert_equal test_files.sort, source.backup_paths.sort
      end
    end

    def test_new_from_file_without_suffix
      source = Source.new test_filename('dmesg')

      test_with_files %w( dmesg ) do |test_files|
        assert_equal test_files, source.backup_paths
      end
    end
  end # Source
end # Backup
