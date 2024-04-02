# frozen_string_literal: true

require 'os'

namespace :mruby_c do
  desc 'Fetches the given version of mruby from github, requires to be installed'
  task :fetch, [:version] do |_t, args|
    version = args[:version] || '3.3.0'

    FileUtils.mkdir_p('./build/')
    FileUtils.rm_rf('./build/mruby') if Dir.exist?('./build/mruby')

    Dir.chdir('./build/') do
      sh "git clone --depth 1 --branch #{version} https://github.com/mruby/mruby/"
    end
  end

  namespace :build do
    desc 'Builds the macos version using clang'
    task mac: [:fetch] do
      full_path = File.expand_path('./config/macos.rb')
      Dir.chdir('./build/mruby') do
        sh "rake MRUBY_CONFIG=#{full_path}"
      end
    end
  end
end
