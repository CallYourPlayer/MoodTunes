require_relative "boot"

require "rails"
# Only require the frameworks this app actually uses.
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile (importmap-rails, tailwindcss-rails,
# httparty, anthropic, etc.).
Bundler.require(*Rails.groups)

module MoodTunes
  class Application < Rails::Application
    config.load_defaults 7.1

    # Autoload app/services and friends.
    config.autoload_lib(ignore: %w[assets tasks])

    # The app is an API-light server-rendered application; no cookies-session
    # complications needed beyond the defaults.
    config.time_zone = "UTC"
  end
end
