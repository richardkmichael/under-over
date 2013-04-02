require 'test/unit'
require 'fileutils'

def test_with_files filenames
  begin
    filenames.each { |f| create_test_file f }
    yield filenames.map { |f| test_filename f }
  ensure
    # If yield fails an assertion, ensure cleanup.
    filenames.each { |f| remove_test_file f }
  end
end

def create_test_file filename
  filename = test_filename filename

  if filename.end_with? '/'
    FileUtils.mkdir(filename).first
  else
    FileUtils.touch(filename).first
  end
end

def remove_test_file filename
  filename = test_filename filename

  if filename.end_with? '/'
    FileUtils.rmdir filename
  else
    FileUtils.rm filename
  end
end

def test_filename filename
  test_filename = File.expand_path File.join(test_files_path, filename)

  # ::expand_path strips the trailing slash, it's needed later - restore if required.
  filename.end_with?('/') ? test_filename << '/' : test_filename
end

def remove_test_files
  if ( test_files_path == nil ) || test_files_path.empty?
    puts "FATAL: Refusing #rm_rf (insane test_files_path: '#{test_files_path}/*'), manual cleanup required."
    exit
  else
    FileUtils.rm_rf Dir["#{test_files_path}/*"]
  end
end

def test_files_path
  @test_files_path ||= begin
                         path = 'test/files'
                         FileUtils.mkdir_p path unless File.exists? path
                         path
                       end
end

def expected_output filenames, output_file
  content = IO.popen("tar ztvf #{output_file}").readlines
  content.map! { |line| line.split(/ +/).last.chomp }
  filenames.sort == content.sort
end

# Helpful with 'assert_equal list, output_file_content(output)' so tests can
# show expectation diffs.
def output_file_content output_file
  content = IO.popen("tar ztvf #{output_file}").readlines
  content.map! { |line| line.split(/ +/).last.chomp }
end

def special_directory_is_renamed link, target
  ( File.readlink(link) + '/') == target
end
