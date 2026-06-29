Rails.application.config.assets.version = "1.0"

# Tailwind output lives here; importmap-rails adds app/javascript automatically.
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")
