# frozen_string_literal: true

require 'os'
require 'json'
require 'minitest/test_task'

require_relative './rakelib/ast_dump_parser'
require_relative './rakelib/odin_producer'

Minitest::TestTask.create do |t|
  t.framework = %(require "tests/test_helper.rb")
  t.libs = %w[test .]
  t.test_globs = ['tests/**/*_test.rb']
end

desc 'Fetches the given version of mruby from github, requires to be installed'
task :fetch, [:version] do |_t, args|
  version = args[:version] || '3.3.0'

  FileUtils.mkdir_p('./build/')
  FileUtils.rm_rf('./build/mruby') if Dir.exist?('./build/mruby')

  Dir.chdir('./build/') do
    sh "git clone --depth 1 --branch #{version} https://github.com/mruby/mruby/"
  end
end

namespace :mac do
  desc 'Builds the macos version using clang'
  task build: [:fetch] do
    FileUtils.mkdir_p('./libs/macos')

    full_path = File.expand_path('./config/macos.rb')
    Dir.chdir('./build/mruby') do
      sh "rake MRUBY_CONFIG=#{full_path}"
    end

    build_dir_path = File.expand_path('./build/mruby/build/host/lib/')

    if Dir.exist?(build_dir_path)
      library_files = Dir.entries(build_dir_path)
                         .select { |f| f.include?('.a') }
                         .map { |f| Pathname.new(build_dir_path).join(f) }
                         .each { |f| FileUtils.cp(f, 'libs/macos/') }
    else
      puts "Error: Build Directory did not get generated #{build_dir_path}"
    end
  end

  desc 'Generates .odin files related to the headers of mruby'
  task gen: [] do
    cmd = 'clang -Xclang -ast-dump=json -c -I build/mruby/build/host/include/ c/mruby.c'
    result = `#{cmd}`
    raise 'Result not created' if result.nil? || result.empty?

    parser = AstDumpParser.from_clang_dump(result)
    parser.parse!

    producer = OdinProducter.new(parser)
    producer.setup!

    puts producer
  end
end
