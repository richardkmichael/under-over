# The testsuite is horrible.
#
# Too much jumping through hoops to create and cleanup test files; file
# creation is "sort-of" chrooted using "test_with_files { .. } ", but the
# Controller needs adjusting in tests for @staging_dirname and
# @output_filename, then adding files must be done with their relative paths to
# the test file directory.  We really just want some kind of 'chroot'
# environment, so that we can still create and cleanup '/var/log/dmesg' without
# touching the real filesystem.

require 'fileutils'

require './test/test_helper'
require './lib/backup_controller.rb'

module Backup
  class ControllerTest < Test::Unit::TestCase

    def setup    ; Controller.reset  ; end
    def teardown ; remove_test_files ; end

    def test_defaults_and_reset

      # Reload the Controller so that setup's ::reset hasn't been run.
      Backup.send :remove_const, 'Controller'
      load './lib/backup_controller.rb'

      @default_output_filename = '/tmp/logs.tgz'
      @default_staging_dirname = '/tmp/logs'

      assert_equal @default_output_filename, Controller.output_filename
      assert_equal @default_staging_dirname, Controller.staging_dirname
      assert_empty Controller.backup_sources

      Controller.output_filename = '/path/to/different_output.tgz'
      Controller.staging_dirname = '/path/to/different_stage_dir'
      Controller.add '/some/source'

      Controller.reset

      assert_equal @default_output_filename, Controller.output_filename
      assert_equal @default_staging_dirname, Controller.staging_dirname
      assert_empty Controller.backup_sources
    end

    def test_change_the_output_file
      output_filename = test_files_path + '/new_logs.tgz'

      Controller.configure do |c|
        c.output_filename = output_filename
      end

      assert_equal output_filename, Controller.output_filename
    end

    def test_change_the_staging_directory
      staging_dirname = test_files_path + '/staging_path'

      Controller.configure do |c|
        c.staging_dirname = staging_dirname
      end

      assert_equal staging_dirname, Controller.staging_dirname
    end

    def test_adds_multiple_sources

      Controller.add test_filename('kern.log'), test_filename('system.log')
      Controller.add test_filename('dmesg')

      assert_equal 3, Controller.backup_sources.count

      test_with_files %w( kern.log dmesg system.log ) do |test_files|
        assert_equal test_files.sort, Controller.backup_sources.sort
      end
    end

    # Testing private methods is smelly, but we care about this one.
    def test_added_special_directories_are_renamed

      staging_dirname = test_files_path + '/staging_path'

      Controller.configure do |c|
        c.staging_dirname = staging_dirname
      end

      Controller.add test_filename('nginx')

      test_with_files %w( nginx/ ) do |test_files|
        Controller.class_eval do
          # Because this reaches fairly deeply into the class, we need to do some setup.  Painful.
          FileUtils.mkdir_p self.staging_dirname unless File.directory? self.staging_dirname
          stage sources.first
        end

        assert special_directory_is_renamed("#{staging_dirname}/web-logs", test_files.first)
      end
    end

    def test_displays_list_of_all_files_to_backup

      Controller.add test_filename('kern.log')

      test_with_files %w( kern.log kern.log.1 kern.log.2.gz ) do |test_files|
        assert_equal test_files.sort, Controller.backup_files
      end
    end

    def test_writes_a_tar_gz_with_sources_having_content

      Controller.configure do |c|
        c.staging_dirname = test_files_path + '/logs'
        c.output_filename = test_files_path + '/logs.tgz'
      end

      Controller.add test_filename('system.log')
      Controller.add test_filename('dmesg')

      test_with_files %w( system.log system.log.1 ) do |test_files|
        Controller.backup
      end

      output = Controller.output_filename
      filename_list = [ 'logs/', 'logs/system-logs/', 'logs/system-logs/system.log', 'logs/system-logs/system.log.1' ]

      assert File.exists? output
      assert_equal filename_list, output_file_content(output), 'Output file does not contain expected content.'
    end

    def test_writes_nothing_with_sources_having_no_content

      Controller.configure do |c|
        c.staging_dirname = test_files_path + '/logs'
        c.output_filename = test_files_path + '/logs.tgz'
      end

      Controller.add test_filename('system.log')

      Controller.backup

      refute File.exists? Controller.output_filename
    end

    def test_behaves_as_required_by_question_without_configuration

      # Reload the Controller so that setup's ::reset hasn't been run.
      Backup.send :remove_const, 'Controller'
      load './lib/backup_controller.rb'

      Controller.add test_filename('does_not_exist')
      Controller.add test_filename('dmesg')
      Controller.add test_filename('syslog')
      Controller.add test_filename('nginx')
      Controller.add test_filename('mysql')

      files_to_create = %w( dmesg dmesg.0 dmesg.1 syslog syslog.0.gz syslog.1.gz nginx/ mysql/ )

      test_with_files files_to_create do |test_files|
        Controller.backup
      end

      output = Controller.output_filename
      filename_list = [ 'logs/',
                        'logs/system-logs/',
                        'logs/system-logs/dmesg',
                        'logs/system-logs/dmesg.0',
                        'logs/system-logs/dmesg.1',
                        'logs/system-logs/syslog',
                        'logs/system-logs/syslog.0.gz',
                        'logs/system-logs/syslog.1.gz',
                        'logs/web-logs/',
                        'logs/database-logs/' ]

      assert File.exists? output
      assert expected_output(filename_list, output), 'Output file does not contain expected content.'
    ensure
      # FIXME: remove_test_files should know how to cleanup any created files, even in /tmp.
      FileUtils.rm_rf Controller.staging_dirname if File.directory? Controller.staging_dirname
      FileUtils.rm Controller.output_filename    if File.file?      Controller.output_filename
    end

    # TODO: Remove staging directory, output file (ideally on runtime fail too).  Finalizer?
    # def test_failed_backup_cleans_up
    #   FileUtils.mkdir Controller.staging_dir
    #   Controller.add test_filename('system.log')
    #   test_with_files %w( system.log ) do |test_files|
    #     Controller.backup
    #   end
    #
    #   assert File.file?(Controller.output_file)
    #   assert File.directory?(Controller.staging_dir + '.1')
    # end

  end
end
