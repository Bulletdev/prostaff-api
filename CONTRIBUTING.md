# Contributing to ProStaff API

Thank you for your interest in contributing to ProStaff API! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Project Architecture](#project-architecture)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing Requirements](#testing-requirements)
- [Security Guidelines](#security-guidelines)
- [Pull Request Process](#pull-request-process)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Review Checklist](#review-checklist)

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Git
- Basic knowledge of Ruby on Rails, PostgreSQL, and Redis

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/bulletdev/prostaff-api.git
cd prostaff-api
```

3. Add upstream remote:

```bash
git remote add upstream https://github.com/bulletdev/prostaff-api.git
```

## Development Environment

### Quick Start

```bash
# Copy environment template
cp .env.example .env

# Start all services
docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs -f api

# Create test user
docker exec prostaff-api-api-1 bundle exec rails runner scripts/create_test_user.rb
```

### Services

- **API**: Rails API (port 3333)
- **PostgreSQL**: Database (port 5432)
- **Redis**: Cache & jobs (port 6380)
- **Sidekiq**: Background jobs
- **Meilisearch**: Full-text search (port 7700)

### Database Migrations

```bash
# Create migration
docker exec prostaff-api-api-1 rails g migration AddFieldToModel

# Run migrations
docker exec prostaff-api-api-1 rails db:migrate

# Rollback
docker exec prostaff-api-api-1 rails db:rollback
```

## Project Architecture

ProStaff API follows a **modular monolith** architecture:

```
app/
├── controllers/api/v1/      # API endpoints
├── models/                  # ActiveRecord models
├── modules/                 # Domain modules (e.g., authentication/)
├── serializers/             # Blueprinter JSON serializers
├── services/                # Business logic
└── queries/                 # Complex query objects
```

### Module Structure

Each module should have:

```
modules/
└── feature_name/
    ├── controllers/
    ├── models/
    ├── services/
    └── README.md
```

## Code Style Guidelines

### Ruby Style

We follow the [Ruby Style Guide](https://rubystyle.guide/) with these key rules:

#### Complexity Limits

- **Cyclomatic Complexity**: Maximum 7 (ideally ≤5)
- **Method Length**: Maximum 50 lines
- **Class Length**: Maximum 150 lines
- **ABC Size**: Maximum 20

#### Good Practices

```ruby
# Use early returns
def process(data)
  return nil unless data.present?
  # processing logic
end

# Extract complex logic to service objects
def create
  result = Users::CreateService.new(user_params, current_organization).call
  render json: result
end

# Use query objects for complex filters
def index
  players = PlayersQuery.new(params, current_organization).call
  render json: { data: players }
end
```

#### Avoid

```ruby
# NO: Multi-line ternary
result = condition ?
  long_expression :
  another_expression

# YES: Use if/else
if condition
  result = long_expression
else
  result = another_expression
end

# NO: Memory-heavy operations
completed = items.select { |i| i.completed? }.count

# YES: Database queries
completed = items.where(status: 'completed').count
```

### Rails Best Practices

1. **Always scope queries by organization** (multi-tenant):

```ruby
# NO - security vulnerability!
@player = Player.find(params[:id])

# YES - scoped to current organization
@player = current_organization.players.find(params[:id])

# YES - using helper
@players = organization_scoped(Player).where(status: 'active')
```

2. **Avoid N+1 queries**:

```ruby
# NO
players.each { |p| p.matches.count }

# YES
players.includes(:matches).each { |p| p.matches.count }
```

3. **Use strong parameters**:

```ruby
def player_params
  params.require(:player).permit(:name, :role, :region, :summoner_name)
end
```

### Documentation

Add YARD documentation to:
- Public API controllers
- Service objects
- Complex model methods

```ruby
# Synchronizes player data from Riot API
#
# @param [String] region The Riot API region (e.g., 'br1', 'na1')
# @param [Boolean] force Force sync even if recently updated
# @return [Hash] Sync result with status and data
# @raise [RiotApi::RateLimitError] if rate limit is exceeded
def sync_from_riot(region:, force: false)
  # implementation
end
```

## Testing Requirements

### Before Committing

Run these tests locally:

```bash
# Security scans
./.pentest/test-ssrf-quick.sh
./.pentest/test-authentication-quick.sh
./.pentest/test-sql-injection-quick.sh
./.pentest/test-secrets-quick.sh

# Code security
./security_tests/scripts/brakeman-scan.sh

# Unit tests
docker exec prostaff-api-api-1 bundle exec rspec
```

### Writing Tests

#### RSpec (Unit Tests)

```ruby
# spec/services/players/create_service_spec.rb
RSpec.describe Players::CreateService do
  let(:organization) { create(:organization) }
  let(:params) { { name: 'Player1', role: 'mid' } }

  it 'creates player scoped to organization' do
    service = described_class.new(params, organization)
    result = service.call

    expect(result[:success]).to be true
    expect(result[:player].organization).to eq(organization)
  end
end
```

#### Load Testing

For performance-critical endpoints:

```bash
./load_tests/run-tests.sh smoke local
```

### Test Coverage

- **Unit tests**: All services, models, and complex logic
- **Security tests**: SSRF, auth, SQL injection, secrets
- **Load tests**: Critical endpoints (dashboard, players list)

## Security Guidelines

**CRITICAL**: Read [SECURITY.md](SECURITY.md) before contributing.

### Security Checklist

Before submitting code:

- [ ] All queries scoped by organization (multi-tenant!)
- [ ] No MD5 hashing (use SHA256/SHA512)
- [ ] Whitelist for URLs with user input
- [ ] No SQL string interpolation (use parameterized queries)
- [ ] No secrets in code (use ENV vars)
- [ ] Controllers use `authenticate_request!`
- [ ] Strong parameters (no `permit!`)
- [ ] Brakeman scan passes (no HIGH/CRITICAL)

### Common Security Mistakes

```ruby
# NO - SQL injection risk
Player.where("name = '#{params[:name]}'")

# YES - parameterized query
Player.where(name: params[:name])

# NO - SSRF vulnerability
HTTParty.get("https://#{params[:region]}.api.riotgames.com")

# YES - whitelist + validation
ALLOWED_REGIONS = %w[br1 na1 euw1 kr].freeze
raise ArgumentError unless ALLOWED_REGIONS.include?(params[:region])
HTTParty.get("https://#{params[:region]}.api.riotgames.com")

# NO - weak hashing
Digest::MD5.hexdigest(data)

# YES - strong hashing
Digest::SHA256.hexdigest(data)
```

## Pull Request Process

### 1. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

Branch naming convention:
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation changes
- `security/` - Security fixes

### 2. Make Changes

- Write clean, readable code
- Follow style guidelines
- Add tests for new functionality
- Update documentation if needed

### 3. Run Tests Locally

```bash
# Security scans
./.pentest/test-ssrf-quick.sh
./.pentest/test-authentication-quick.sh
./.pentest/test-sql-injection-quick.sh
./.pentest/test-secrets-quick.sh

# Code quality
./security_tests/scripts/brakeman-scan.sh

# Unit tests
docker exec prostaff-api-api-1 bundle exec rspec
```

### 4. Commit Changes

Follow [commit message guidelines](#commit-message-guidelines).

```bash
git add .
git commit -m "feat: add player statistics caching"
```

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Create pull request on GitHub with:
- Clear title describing the change
- Description of what changed and why
- Reference to related issues (if any)
- Screenshots (for UI changes)

### 6. Code Review

- Address reviewer feedback
- Keep PR focused and small (< 400 lines if possible)
- Respond to comments promptly
- Update PR description if scope changes

### 7. Merge

Once approved:
- Squash commits if requested
- Maintainer will merge PR
- Delete feature branch after merge

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no functionality change)
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `chore`: Maintenance tasks (dependencies, config)
- `security`: Security fixes

### Examples

```
feat(players): add KDA calculation to player stats

fix(auth): resolve JWT expiration check bug

refactor(dashboard): extract stats calculation to service

perf(queries): add database index for player lookups

security(ssrf): add domain whitelist validation
```

### Rules

- Use imperative mood ("add" not "added" or "adds")
- Don't capitalize first letter
- No period at the end
- Keep first line under 72 characters
- Reference issues: `fixes #123` or `closes #456`

## Review Checklist

### For Contributors

Before submitting PR:

- [ ] Code follows style guidelines
- [ ] All tests pass locally
- [ ] Security scans pass (Brakeman)
- [ ] No secrets in code
- [ ] Documentation updated (if needed)
- [ ] Commit messages follow guidelines
- [ ] PR description is clear and complete

### For Reviewers

When reviewing PR:

**Security** (CRITICAL):
- [ ] Queries scoped by organization
- [ ] No MD5 hashing
- [ ] Whitelist for user-provided URLs
- [ ] No SQL string interpolation
- [ ] No hardcoded secrets

**Code Quality**:
- [ ] Cyclomatic complexity ≤ 7
- [ ] Methods ≤ 50 lines
- [ ] Classes ≤ 150 lines
- [ ] No N+1 queries
- [ ] Proper error handling

**Testing**:
- [ ] Tests cover new functionality
- [ ] Edge cases handled
- [ ] Security tests updated (if applicable)

**Documentation**:
- [ ] YARD docs for public methods
- [ ] README updated (if needed)
- [ ] Comments explain "why" not "what"

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Security**: Email security@prostaff.gg (see [SECURITY.md](SECURITY.md))
- **Chat**: Join our Discord (link in README)

## Additional Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Ruby Style Guide](https://rubystyle.guide/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Brakeman Scanner](https://brakemanscanner.org/)
- [Project README](README.md)
- [Security Policy](SECURITY.md)

## License

By contributing to ProStaff API, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to ProStaff API!**

We appreciate your time and effort in making this project better.

---

**Last Updated**: 2026-03-04
**Maintainer**: ProStaff Team
