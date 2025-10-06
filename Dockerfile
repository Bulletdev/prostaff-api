# Use Ruby 3.4.5 slim image (better Windows compatibility)
FROM ruby:3.4.5-slim

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    tzdata \
    nodejs \
    npm \
    curl \
    && npm install -g yarn \
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

# Change ownership of the app directory
RUN chown -R app:app /app

# Switch to the app user
USER app

# Expose port 3333
EXPOSE 3333

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3333/up || exit 1

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]