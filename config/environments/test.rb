# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Configure 'rails notes' to inspect Cucumber files
  config.annotations.register_directories("features")
  config.annotations.register_extensions("feature") { |tag| /#\s*(#{tag}):?\s*(.*)$/ }

  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  

  # ✅ Windows fix — disable Sprockets cache to avoid file rename errors
  if Gem.win_platform?
    config.assets.configure do |env|
      env.cache = ActiveSupport::Cache::NullStore.new
    end

    # ✅ Also silence asset logging so Sprockets doesn't try to rewrite files
    config.assets.quiet = true
    config.assets.enabled = false
  end

  # Eager loading loads your entire application.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true

  # Disable Rails caching.
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Emails are not delivered.
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.com" }

  # Print deprecation warnings.
  config.active_support.deprecation = :stderr

  # Raise error when a before_action's only/except references a missing action.
  config.action_controller.raise_on_missing_callback_actions = true
end
