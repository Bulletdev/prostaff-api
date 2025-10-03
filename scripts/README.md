# Architecture Diagram Auto-Update System

## Overview

This directory contains the automated system for keeping the architecture diagram in the README.md synchronized with the actual project structure.

## How It Works

### 1. Script: `update_architecture_diagram.rb`

The Ruby script analyzes the Rails application structure and generates a Mermaid diagram that reflects:

- **Modules**: Discovered from `app/modules/` directory
- **Models**: Scanned from `app/models/`
- **Controllers**: Found in module controllers and API controllers
- **Services**: Located in module services directories
- **Routes**: Analyzed from `config/routes.rb`
- **Dependencies**: Detected from `Gemfile` (Redis, Sidekiq, Riot API integration)

### 2. GitHub Actions Workflow

Location: `.github/workflows/update-architecture-diagram.yml`

**Triggers:**
- Push to `master` or `main` branch
- Pull requests to `master` or `main` branch
- Manual workflow dispatch
- When changes occur in:
  - `app/modules/**`
  - `app/models/**`
  - `app/controllers/**`
  - `config/routes.rb`
  - `Gemfile`

**Process:**
1. Checks out the code
2. Sets up Ruby environment
3. Runs the update script
4. Checks if README.md was modified
5. Commits and pushes changes (if any)

## Manual Usage

To manually update the architecture diagram:

```bash
ruby scripts/update_architecture_diagram.rb
```

This is useful when:
- Testing diagram changes locally
- Verifying the diagram before committing
- Making custom adjustments to the architecture section

## Architecture Components

The generated diagram includes:

### Client Layer
- Frontend application interface

### API Gateway
- Rails Router
- CORS Middleware
- Rate Limiting (Rack::Attack)
- Authentication Middleware (JWT)

### Application Layer - Modular Monolith
Each module is automatically discovered and represented with:
- Controllers
- Models
- Services

Current modules:
- **Authentication**: User auth, JWT tokens
- **Dashboard**: Statistics and metrics
- **Players**: Player management
- **Scouting**: Talent discovery
- **Analytics**: Performance analysis
- **Matches**: Match data
- **Schedules**: Event management
- **VOD Reviews**: Video reviews
- **Team Goals**: Goal tracking
- **Riot Integration**: External API integration

### Data Layer
- PostgreSQL (persistent storage)
- Redis (caching and job queue)

### Background Jobs
- Sidekiq workers
- Job queue management

### External Services
- Riot Games API

## Customizing the Diagram

To modify the diagram generation logic, edit `update_architecture_diagram.rb`:

1. **Add new module detection**: Update `discover_modules()` method
2. **Change connection logic**: Modify `generate_*_connections()` methods
3. **Adjust styling**: Update the `style` lines in the Mermaid output
4. **Add new layers**: Create new `generate_*_section()` methods

## Benefits

1. **Always Up-to-Date**: Diagram automatically reflects code structure
2. **Documentation Quality**: Reduces documentation drift
3. **Onboarding**: New developers see accurate architecture
4. **Change Visibility**: Architecture changes are tracked in git history
5. **No Manual Work**: Eliminates need for manual diagram updates

## Best Practices

1. **Review Diagram Changes**: Check the auto-generated diagram in PRs
2. **Module Naming**: Use clear, consistent module names in `app/modules/`
3. **Model Organization**: Keep models in standard locations for auto-discovery
4. **Service Patterns**: Follow consistent naming conventions for services

## Troubleshooting

**Diagram not updating:**
- Check workflow logs in GitHub Actions
- Verify paths in workflow triggers
- Ensure script has execution permissions

**Incorrect connections:**
- Review `config/routes.rb` for routing information
- Check model relationships
- Verify service discovery logic

**Missing modules:**
- Ensure modules are in `app/modules/`
- Check directory structure matches expected pattern
- Verify controller and service naming conventions
