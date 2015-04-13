require 'rake'
require 'json'
require 'pathname'

namespace :tahi do
  desc 'Install a tahi engine for a git repo or local path'
  task :install_plugin, [:git_or_file_path] => :environment do |_, args|
    path = args[:git_or_file_path]
    fail "Please supply a git or file path!" if path.nil?
    needle = '# Task Engines'
    gem_type = if path.match(/^(http|git)/)
                 'git'
               else
                 'path'
               end
    engine_name = path.split(/\//)[-1].gsub(/^tahi-/, '').gsub(/.git$/, '')
    insert_after('Gemfile', needle, "gem '#{engine_name}', #{gem_type}: '#{path}'")
    Bundler.with_clean_env do
      sh 'bundle install'
    end
    Bundler.with_clean_env do
      # need to do this in subshell because our ruby process doesn't
      # know about the engine yet
      migration_task = "#{engine_name}:install:migrations"
      sh "bundle exec rake #{migration_task}" if `bundle exec rake -T #{migration_task}`.size > 0
      # tahi magic installer
      sh "bundle exec rake data:create_task_types"
    end

    # modify route
    needle = "### DO NOT DELETE OR EDIT. AUTOMATICALLY MOUNTED CUSTOM TASK CARDS GO HERE ###"
    insert_after("config/routes.rb", needle, "  mount #{engine_name.camelize}::Engine => '/api'")

    # modify application.scss
    needle = "// DO NOT DELETE OR EDIT. AUTOMATICALLY MOUNTED CUSTOM TASK CARDS GO HERE"
    insert_after("app/assets/stylesheets/application.scss", needle, "@import '#{engine_name}/application';")
  end

  def relative_path(to, from)
    Pathname.new(to).relative_path_from(Pathname.new(from))
  end

  # This should just use Rails::Generators or Thor's inject_into_file(:before) method
  def insert_before(filename, needle, string)
    hay = File.open(filename, "r").read
    needle_index = hay.index(needle)
    updated_string = hay.insert(needle_index, "#{string}\n")

    File.open(filename, "w") do |f|
      f << updated_string
      puts "updated #{filename}"
    end
  end

  # This should just use Rails::Generators or Thor's inject_into_file(:after) method
  def insert_after(filename, needle, string)
    hay = File.open(filename, "r").read
    needle_index = hay.index(needle)
    updated_string = hay.insert(needle_index + needle.length, "\n#{string}")

    File.open(filename, "w") do |f|
      f << updated_string
      puts "updated #{filename}"
    end
  end
end
