require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Static files are served by the app on Render when RAILS_SERVE_STATIC_FILES is set.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Assets are precompiled during the build step.
  config.assets.compile = false

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id]

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.action_dispatch.show_exceptions = :all
end
