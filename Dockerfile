FROM ruby:3.3.6-slim

ENV RAILS_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    LANG=C.UTF-8

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client \
      git \
      curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Bundle install
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && \
    bundle install --without development test

# App
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Permessi
RUN chmod +x bin/* || true

# Porta dinamica
EXPOSE 3000

# ✅ usa PORT di Render
CMD ["sh", "-c", "bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}"]