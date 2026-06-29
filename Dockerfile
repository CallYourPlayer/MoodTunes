# Development-oriented image for Docker Compose.
FROM ruby:3.3.6-slim

ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    LANG=C.UTF-8

# System dependencies: build tools + PostgreSQL client libs.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client \
      git \
      curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems first for better layer caching.
COPY Gemfile Gemfile.lock* ./
RUN gem install bundler && bundle install

# Copy the rest of the application.
COPY . .

RUN chmod +x bin/* || true

ENTRYPOINT ["bin/docker-entrypoint"]

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
