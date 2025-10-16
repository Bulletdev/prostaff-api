[![Security Scan](https://github.com/Bulletdev/prostaff-api/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Bulletdev/prostaff-api/actions/workflows/security-scan.yml)
[![Ruby Version](https://img.shields.io/badge/ruby-3.4.5-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-7.2-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue.svg?logo=postgresql)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-6+-red.svg?logo=redis)](https://redis.io/)
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

# ProStaff API

Ruby on Rails API for the ProStaff.gg esports team management platform.

##  Quick Start

```bash
docker compose up -d

docker exec prostaff-api-api-1 rails runner scripts/create_test_user.rb

./load_tests/run-tests.sh smoke local
./security_tests/scripts/brakeman-scan.sh
```

## Technology Stack

- **Ruby**: 3.4.5
- **Rails**: 7.1+ (API-only mode)
- **Database**: PostgreSQL 14+
- **Authentication**: JWT
- **Background Jobs**: Sidekiq
- **Caching**: Redis (port 6380)
- **Testing**: RSpec, k6, OWASP ZAP

## Architecture

This API follows a modular monolith architecture with the following modules:

- `authentication` - User authentication and authorization
- `dashboard` - Dashboard statistics and metrics
- `players` - Player management and statistics
- `scouting` - Player scouting and talent discovery
- `analytics` - Performance analytics and reporting
- `matches` - Match data and statistics
- `schedules` - Event and schedule management
- `vod_reviews` - Video review and timestamp management
- `team_goals` - Goal setting and tracking
- `riot_integration` - Riot Games API integration

### Architecture Diagram

```mermaid
graph TB
    subgraph "Client Layer"
        Client[Frontend Application]
    end

    subgraph "API Gateway"
        Router[Rails Router]
        CORS[CORS Middleware]
        RateLimit[Rate Limiting]
        Auth[Authentication Middleware]
    end

    subgraph "Application Layer - Modular Monolith"
subgraph "Authentication Module"
    AuthController[Auth Controller]
    JWTService[JWT Service]
    UserModel[User Model]
end
subgraph "Dashboard Module"
    DashboardController[Dashboard Controller]
    DashStats[Statistics Service]
end
subgraph "Players Module"
    PlayersController[Players Controller]
    PlayerModel[Player Model]
    ChampionPool[Champion Pool Model]
end
subgraph "Scouting Module"
    ScoutingController[Scouting Controller]
    ScoutingTarget[Scouting Target Model]
    Watchlist[Watchlist Service]
end
subgraph "Analytics Module"
    AnalyticsController[Analytics Controller]
    PerformanceService[Performance Service]
    KDAService[KDA Trend Service]
end
subgraph "Matches Module"
    MatchesController[Matches Controller]
    MatchModel[Match Model]
    PlayerMatchStats[Player Match Stats Model]
end
subgraph "Schedules Module"
    SchedulesController[Schedules Controller]
    ScheduleModel[Schedule Model]
end
subgraph "VOD Reviews Module"
    VODController[VOD Reviews Controller]
    VODModel[VOD Review Model]
    TimestampModel[Timestamp Model]
end
subgraph "Team Goals Module"
    GoalsController[Team Goals Controller]
    GoalModel[Team Goal Model]
end
subgraph "Riot Integration Module"
    RiotService[Riot API Service]
    RiotSync[Sync Service]
end
    end

    subgraph "Data Layer"
        PostgreSQL[(PostgreSQL Database)]
        Redis[(Redis Cache)]
    end

    subgraph "Background Jobs"
        Sidekiq[Sidekiq Workers]
        JobQueue[Job Queue]
    end

    subgraph "External Services"
        RiotAPI[Riot Games API]
    end

    Client -->|HTTP/JSON| CORS
    CORS --> RateLimit
    RateLimit --> Auth
    Auth --> Router
    
    Router --> AuthController
    Router --> DashboardController
    Router --> PlayersController
    Router --> ScoutingController
    Router --> AnalyticsController
    Router --> MatchesController
    Router --> SchedulesController
    Router --> VODController
    Router --> GoalsController
    AuthController --> JWTService
    AuthController --> UserModel
    PlayersController --> PlayerModel
    PlayerModel --> ChampionPool
    ScoutingController --> ScoutingTarget
    ScoutingController --> Watchlist
    MatchesController --> MatchModel
    MatchModel --> PlayerMatchStats
    SchedulesController --> ScheduleModel
    VODController --> VODModel
    VODModel --> TimestampModel
    GoalsController --> GoalModel
    AnalyticsController --> PerformanceService
    AnalyticsController --> KDAService
    AuditLogModel[AuditLog Model] --> PostgreSQL
    ChampionPoolModel[ChampionPool Model] --> PostgreSQL
    MatchModel[Match Model] --> PostgreSQL
    NotificationModel[Notification Model] --> PostgreSQL
    OrganizationModel[Organization Model] --> PostgreSQL
    PasswordResetTokenModel[PasswordResetToken Model] --> PostgreSQL
    PlayerModel[Player Model] --> PostgreSQL
    PlayerMatchStatModel[PlayerMatchStat Model] --> PostgreSQL
    ScheduleModel[Schedule Model] --> PostgreSQL
    ScoutingTargetModel[ScoutingTarget Model] --> PostgreSQL
    TeamGoalModel[TeamGoal Model] --> PostgreSQL
    TokenBlacklistModel[TokenBlacklist Model] --> PostgreSQL
    UserModel[User Model] --> PostgreSQL
    VodReviewModel[VodReview Model] --> PostgreSQL
    VodTimestampModel[VodTimestamp Model] --> PostgreSQL
    JWTService --> Redis
    DashStats --> Redis
    PerformanceService --> Redis
PlayersController --> RiotService
MatchesController --> RiotService
ScoutingController --> RiotService
RiotService --> RiotAPI

RiotService --> Sidekiq
Sidekiq --> JobQueue
JobQueue --> Redis
    
    style Client fill:#e1f5ff
    style PostgreSQL fill:#336791
    style Redis fill:#d82c20
    style RiotAPI fill:#eb0029
    style Sidekiq fill:#b1003e
```


**Key Architecture Principles:**

1. **Modular Monolith**: Each module is self-contained with its own controllers, models, and services
2. **API-Only**: Rails configured in API mode for JSON responses
3. **JWT Authentication**: Stateless authentication using JWT tokens
4. **Background Processing**: Long-running tasks handled by Sidekiq
5. **Caching**: Redis used for session management and performance optimization
6. **External Integration**: Riot Games API integration for real-time data
7. **Rate Limiting**: Rack::Attack for API rate limiting
8. **CORS**: Configured for cross-origin requests from frontend

## Setup

### Prerequisites

- Ruby 3.2+
- PostgreSQL 14+
- Redis 6+

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd prostaff-api
```

2. Install dependencies:
```bash
bundle install
```

3. Setup environment variables:
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
- Database credentials
- JWT secret key
- Riot API key
- Redis URL
- CORS origins

4. Setup the database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

5. Start the services:

Start Redis:
```bash
redis-server
```

Start Sidekiq (in another terminal):
```bash
bundle exec sidekiq
```

Start the Rails server:
```bash
rails server
```

The API will be available at `http://localhost:3333`

## API Documentation

### Base URL
```
http://localhost:3333/api/v1
```

### Authentication

All endpoints (except auth endpoints) require a Bearer token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Authentication Endpoints

- `POST /auth/register` - Register new organization and admin user
- `POST /auth/login` - Login user
- `POST /auth/refresh` - Refresh JWT token
- `POST /auth/logout` - Logout user
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/reset-password` - Reset password
- `GET /auth/me` - Get current user info

### Core Endpoints

#### Dashboard
- `GET /dashboard` - Get complete dashboard data
- `GET /dashboard/stats` - Get quick stats
- `GET /dashboard/activities` - Get recent activities
- `GET /dashboard/schedule` - Get upcoming schedule

#### Players
- `GET /players` - List players
- `GET /players/:id` - Get player details
- `POST /players` - Create player
- `PATCH /players/:id` - Update player
- `DELETE /players/:id` - Delete player
- `GET /players/stats` - Get roster statistics
- `POST /players/import` - Import player from Riot API

#### Matches
- `GET /matches` - List matches
- `GET /matches/:id` - Get match details
- `POST /matches` - Create match
- `POST /matches/import` - Import match from Riot API

#### Scouting
- `GET /scouting/players` - List scouting targets
- `GET /scouting/regions` - Get available regions
- `POST /scouting/players` - Add scouting target

#### Analytics
- `GET /analytics/performance` - Player performance data
- `GET /analytics/champions/:player_id` - Champion statistics
- `GET /analytics/kda-trend/:player_id` - KDA trend analysis

## Testing

Run the test suite:

```bash
bundle exec rspec
```

## Deployment

### Environment Variables

Required environment variables for production:

```bash
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://host:6379/0
JWT_SECRET_KEY=your-production-secret
RIOT_API_KEY=your-riot-api-key
CORS_ORIGINS=https://your-frontend-domain.com
SECRET_KEY_BASE=your-rails-secret
```

### Docker

A Dockerfile is provided for containerized deployment:

```bash
docker build -t prostaff-api .
docker run -p 3333:3000 prostaff-api
```

## CI/CD

### Architecture Diagram Auto-Update

This project includes an automated workflow that keeps the architecture diagram in sync with the codebase:

- **Trigger**: Automatically runs when changes are made to:
  - `app/modules/**` - Module definitions
  - `app/models/**` - Data models
  - `app/controllers/**` - Controllers
  - `config/routes.rb` - Route definitions
  - `Gemfile` - Dependencies

- **Process**: 
  1. GitHub Actions workflow detects relevant code changes
  2. Runs `scripts/update_architecture_diagram.rb`
  3. Script analyzes project structure (modules, models, controllers, services)
  4. Generates updated Mermaid diagram
  5. Updates README.md with new diagram
  6. Commits changes back to the repository

- **Manual Update**: You can also manually update the diagram:
  ```bash
  ruby scripts/update_architecture_diagram.rb
  ```

The diagram automatically reflects:
- New modules added to `app/modules/`
- New models created
- New controllers and routes
- Service integrations (Riot API, Redis, PostgreSQL, Sidekiq)

## 📊 Performance & Testing

### Load Testing (k6)

```bash
# Quick smoke test (1 min)
./load_tests/run-tests.sh smoke local

# Full load test (16 min)
./load_tests/run-tests.sh load local

# Stress test (28 min)
./load_tests/run-tests.sh stress local
```

**Current Performance**:
- p(95): ~880ms (Docker dev)
- Production estimate: ~500ms
- With cache: ~50ms
- Error rate: 0%

**Documentation**: See [TESTING_GUIDE.md](DOCS/tests/TESTING_GUIDE.md) and [QUICK_START.md](DOCS/setup/QUICK_START.md)

### Security Testing (OWASP)

```bash
# Complete security audit
./security_tests/scripts/full-security-audit.sh

# Individual scans
./security_tests/scripts/brakeman-scan.sh          # Code analysis
./security_tests/scripts/dependency-scan.sh        # Vulnerable gems
./security_tests/scripts/zap-baseline-scan.sh      # Web app scan
```

**Coverage**:
- ✅ OWASP Top 10
- ✅ Code security (Brakeman)
- ✅ Dependency vulnerabilities
- ✅ Runtime security (ZAP)
- ✅ CI/CD integration

**Documentation**: See [security_tests/README.md](security_tests/README.md)

### CI/CD Workflows

Automated testing on every push:
- **Security Scan**: Brakeman + dependency check
- **Load Test**: Nightly smoke tests
- **Nightly Audit**: Complete security scan

See `.github/workflows/` for details.

## Contributing

1. Create a feature branch
2. Make your changes
3. Add tests
4. **Run security scan**: `./security_tests/scripts/brakeman-scan.sh`
5. Ensure all tests pass
6. Submit a pull request

**Note**: The architecture diagram will be automatically updated when you add new modules, models, or controllers.
## License

Copyright e Licenciamento

© 2025 ProStaff.gg. Todos os direitos reservados.

Este repositório contém o código-fonte oficial da API para a plataforma de e-sports ProStaff.gg.

O código-fonte contido aqui é disponibilizado sob a licença Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
Você pode encontrar o texto completo da licença no arquivo [LICENSE](license.md) neste repositório.

Shield:

[![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg