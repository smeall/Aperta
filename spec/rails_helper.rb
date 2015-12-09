require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

ENV["RAILS_ENV"] ||= 'test'
require 'spec_helper'
require File.expand_path("../../config/environment", __FILE__)
require 'capybara-screenshot/rspec'
require 'capybara/rspec'
require 'email_spec'
require 'pusher-fake/support/rspec'
require 'rspec/rails'
require 'sidekiq/testing'
require 'webmock/rspec'
require 'rake'
include Warden::Test::Helpers

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
require_relative 'support/pages/page'
require_relative 'support/pages/overlay'
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

Tahi.service_log = Logger.new "#{::Rails.root}/log/service.log"

# Load support & factories for installed Tahi plugins
TahiPlugin.plugins.each do |gem|
  Dir[File.join(gem.full_gem_path, 'spec', 'support', '**', '*.rb')].each { |f| require f }
  Dir[File.join(gem.full_gem_path, 'spec', 'factories', '**', '*.rb')].each { |f| require f }
end

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = false
  config.default_cassette_options = { record: :once }
  config.configure_rspec_metadata!
  config.ignore_hosts 'codeclimate.com'
  config.ignore_localhost = true
end
# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema! if
  defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/v/3-0/docs
  config.infer_spec_type_from_file_location!
  config.order = 'random'

  config.include Devise::TestHelpers, type: :controller
  config.include FactoryGirl::Syntax::Methods
  config.include TahiHelperMethods
  config.extend TahiHelperClassMethods
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers

  config.before(:suite) do
    # Necessary to run a rake task from here
    Rake::Task.clear
    Tahi::Application.load_tasks
    # Load question seeds before any tests start since we don't want them
    # to be rolled back as part of a transaction
    Rake::Task['nested-questions:seed'].invoke
    DatabaseCleaner[:active_record].strategy = :transaction
    Warden.test_mode!
  end

  config.before(:context) do
    UploadServer.clear_all_uploads
    Sidekiq::Worker.clear_all
  end

  config.before(:context, js: true) do
    # Fix to make sure this happens only once
    # This cannot be a :suite block, because that does not know if a js feature
    # is being run.
    # rubocop:disable Style/GlobalVars
    next if $capybara_setup_done
    EmberCLI.compile!
    Capybara.server_port = ENV['CAPYBARA_SERVER_PORT']

    # This allows the developer to specify a path to an older, insecure firefox
    # build for use in selenium tests. The value of the environment variable
    # should be a full path to the firefox binary.
    Selenium::WebDriver::Firefox::Binary.path = ENV['SELENIUM_FIREFOX_PATH'] if
      ENV['SELENIUM_FIREFOX_PATH']
    Capybara.register_driver :selenium do |app|
      profile = Selenium::WebDriver::Firefox::Profile.new
      client = Selenium::WebDriver::Remote::Http::Default.new
      client.timeout = 90
      Capybara::Selenium::Driver
        .new(app, browser: :firefox, profile: profile, http_client: client)
    end

    Capybara.javascript_driver = :selenium
    Capybara.default_max_wait_time = 10
    Capybara.wait_on_first_by_default = true

    # Store screenshots in artifacts dir on circle
    if ENV['CIRCLE_TEST_REPORTS']
      Capybara.save_and_open_page_path =
        "#{ENV['CIRCLE_TEST_REPORTS']}/screenshots/"
    end
    $capybara_setup_done = true
    # rubocop:enable Style/GlobalVars
  end

  config.before(:context, js: true) do
    # Fix to make sure this happens only once
    # This cannot be a :suite block, because that does not know if a js feature
    # is being run.
    # rubocop:disable Style/GlobalVars
    next if $capybara_setup_done
    EmberCLI.compile!
    Capybara.server_port = ENV['CAPYBARA_SERVER_PORT']

    # This allows the developer to specify a path to an older, insecure firefox
    # build for use in selenium tests. The value of the environment variable
    # should be a full path to the firefox binary.
    Selenium::WebDriver::Firefox::Binary.path = ENV['SELENIUM_FIREFOX_PATH'] if
      ENV['SELENIUM_FIREFOX_PATH']
    Capybara.register_driver :selenium do |app|
      profile = Selenium::WebDriver::Firefox::Profile.new
      client = Selenium::WebDriver::Remote::Http::Default.new
      client.timeout = 90
      Capybara::Selenium::Driver
        .new(app, browser: :firefox, profile: profile, http_client: client)
    end

    Capybara.javascript_driver = :selenium
    Capybara.default_max_wait_time = 10
    Capybara.wait_on_first_by_default = true

    # Store screenshots in artifacts dir on circle
    if ENV['CIRCLE_TEST_REPORTS']
      Capybara.save_and_open_page_path =
        "#{ENV['CIRCLE_TEST_REPORTS']}/screenshots/"
    end
    $capybara_setup_done = true
    # rubocop:enable Style/GlobalVars
  end

  config.before(:each, js: true) do
    # :truncation is the strategy we need to use for capybara tests, but do not
    # truncate task_types and nested_questions, we want to keep these tables
    # around.
    DatabaseCleaner[:active_record].strategy = :truncation, {
      except: %w(task_types nested_questions) }
    Capybara.page.driver.browser.manage.window.resize_to(1500, 1000)
  end

  config.before(:each) do
    ActionMailer::Base.deliveries.clear
    DatabaseCleaner.start
    Subscriptions.clear_all_subscriptions!
  end

  # Load subscriptions for feature specs. Make sure this comes *after*
  # clean_all_subscriptions! We need to add these back.
  config.before(:context, type: :feature) do
    load Rails.root.join('config/initializers/event_stream_subscriptions.rb')
    load Rails.root.join('config/initializers/subscriptions.rb')
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end

  config.after(:each) do
    Warden.test_reset!
  end
end
