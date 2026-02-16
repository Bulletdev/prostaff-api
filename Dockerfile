# Use Ruby 3.4.5 slim image (better Windows compatibility)
FROM ruby:3.4.5-slim

# Install system dependencies with version pinning and no recommended packages
# Note: Versions are pinned for security and reproducibility
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    libpq-dev=15.10-0+deb12u1 \
    libyaml-dev=0.2.5-1+deb12u1 \
    git=1:2.39.5-0+deb12u1 \
    tzdata=2024a-0+deb12u1 \
    nodejs=18.19.0+dfsg-6~deb12u2 \
    npm=9.2.0~ds1-1 \
    curl=7.88.1-10+deb12u8 \
    && npm install -g yarn@1.22.22 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile (and Gemfile.lock if it exists)
COPY Gemfile ./
COPY Gemfile.lock* ./

# Install Ruby dependencies
RUN bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Create user to run the application
RUN groupadd -g 1000 app && \
    useradd -u 1000 -g app -m -s /bin/bash app

# Change ownership of the app directory and bundle directory
RUN chown -R app:app /app /usr/local/bundle

# Switch to the app user
USER app

# Expose port 3000 (Rails default)
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]