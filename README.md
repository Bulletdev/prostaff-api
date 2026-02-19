
```
>        ██████╗ ██████╗  ██████╗ ███████╗████████╗ █████╗ ███████╗███████╗
>        ██╔══██╗██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔══██╗██╔════╝██╔════╝
>        ██████╔╝██████╔╝██║   ██║███████╗   ██║   ███████║█████╗  █████╗
>        ██╔═══╝ ██╔══██╗██║   ██║╚════██║   ██║   ██╔══██║██╔══╝  ██╔══╝
>        ██║     ██║  ██║╚██████╔╝███████║   ██║   ██║  ██║██║     ██║
>        ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝
                  API — eSports Analytics Hub - ProStaff.gg
```

<div align="center">

[![Security Scan](https://github.com/Bulletdev/prostaff-api/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Bulletdev/prostaff-api/actions/workflows/security-scan.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/30bf4e093ece4ceb8ea46dbe7aecdee1)](https://app.codacy.com/gh/Bulletdev/prostaff-api/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

[![Ruby Version](https://img.shields.io/badge/ruby-3.4.5-CC342D?logo=ruby)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-7.2-CC342D?logo=rubyonrails)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue.svg?logo=postgresql)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-6+-red.svg?logo=redis)](https://redis.io/)
[![Swagger](https://img.shields.io/badge/API-Swagger-85EA2D?logo=swagger)](http://localhost:3333/api-docs)
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

</div>

---

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PROSTAFF API — Ruby on Rails 7.2 (API-Only)                                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Backend for the ProStaff.gg esports team management platform.               ║
║  200+ documented endpoints · JWT Auth · Modular Monolith · p95 ~500ms        ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

<details>
<summary><kbd>▶ Key Features (click to expand)</kbd></summary>

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [■] JWT Authentication       — Refresh tokens + token blacklisting         │
│  [■] HashID URLs              — Base62 encoding for obfuscated URLs         │
│  [■] Swagger Docs             — 200+ endpoints documented interactively     │
│  [■] Riot Games API           — Automatic match and player import           │
│  [■] Advanced Analytics       — KDA trends, champion pools, vision control  │
│  [■] Scouting System          — Talent discovery + watchlist management     │
│  [■] VOD Review System        — Collaborative timestamp annotations         │
│  [■] Schedule Management      — Matches, scrims and team events             │
│  [■] Goal Tracking            — Performance goals (team and players)        │
│  [■] Competitive Module       — PandaScore integration + draft analysis     │
│  [■] Scrims Management        — Opponent tracking + analytics               │
│  [■] Strategy Module          — Draft planning + tactical boards            │
│  [■] Support System           — Ticketing + staff dashboard + FAQ           │
│  [■] Background Jobs          — Sidekiq for async background processing     │
│  [■] Security Hardened        — OWASP Top 10, Brakeman, ZAP tested          │
│  [■] High Performance         — p95: ~500ms · cached: ~50ms                 │
│  [■] Modular Monolith         — Scalable modular architecture               │
└─────────────────────────────────────────────────────────────────────────────┘
```

</details>

---

## Table of Contents

```
┌──────────────────────────────────────────────────────┐
│  01 · Quick Start                                    │
│  02 · Technology Stack                               │
│  03 · Architecture                                   │
│  04 · Setup                                          │
│  05 · Development Tools                              │
│  06 · API Documentation                              │
│  07 · Testing                                        │
│  08 · Performance & Load Testing                     │
│  09 · Security                                       │
│  10 · Deployment                                     │
│  11 · CI/CD                                          │
│  12 · Contributing                                   │
│  13 · License                                        │
└──────────────────────────────────────────────────────┘
```

---

## 01 · Quick Start

<details>
<summary><kbd>▶ Option 1: Docker (Recommended)</kbd></summary>

```bash
# Start all services (API, PostgreSQL, Redis, Sidekiq)
docker compose up -d

# Create test user
docker exec prostaff-api-api-1 rails runner scripts/create_test_user.rb

# Get JWT token for testing
./scripts/get-token.sh

# Access API docs
open http://localhost:3333/api-docs

# Run smoke tests
./load_tests/run-tests.sh smoke local

# Run security scan
./security_tests/scripts/brakeman-scan.sh
```

</details>

<details>
<summary><kbd>▶ Option 2: Local Development (Without Docker)</kbd></summary>

```bash
# Install dependencies
bundle install

# Generate secrets
./scripts/generate_secrets.sh  # Copy output to .env

# Setup database
rails db:create db:migrate db:seed

# Start Redis (in separate terminal)
redis-server

# Start Sidekiq (in separate terminal)
bundle exec sidekiq

# Start Rails server
rails server -p 3333

# Get JWT token for testing
./scripts/get-token.sh

# Access API docs
open http://localhost:3333/api-docs
```

</details>

```
  API:          http://localhost:3333
  Swagger Docs: http://localhost:3333/api-docs
```

---

## 02 · Technology Stack

```
╔══════════════════════╦════════════════════════════════════════════════════╗
║  CAMADA              ║  TECNOLOGIA                                        ║
╠══════════════════════╬════════════════════════════════════════════════════╣
║  Language            ║  Ruby 3.4.5                                        ║
║  Framework           ║  Rails 7.2.0 (API-only mode)                       ║
║  Database            ║  PostgreSQL 14+                                    ║
║  Authentication      ║  JWT (access + refresh tokens)                     ║
║  URL Obfuscation     ║  HashID with Base62 encoding                       ║
║  Background Jobs     ║  Sidekiq                                           ║
║  Caching             ║  Redis (port 6380)                                 ║
║  API Documentation   ║  Swagger/OpenAPI 3.0 (rswag)                       ║
║  Testing             ║  RSpec, Integration Specs, k6, OWASP ZAP           ║
║  Authorization       ║  Pundit                                            ║
║  Serialization       ║  Blueprinter                                       ║
╚══════════════════════╩════════════════════════════════════════════════════╝
```

---

## 03 · Architecture

This API follows a **modular monolith** architecture:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  MODULE             │  RESPONSIBILITY                                       │
├─────────────────────┼───────────────────────────────────────────────────────┤
│  authentication     │  User auth and authorization                          │
│  dashboard          │  Dashboard statistics and metrics                     │
│  players            │  Player management and statistics                     │
│  scouting           │  Player scouting and talent discovery                 │
│  analytics          │  Performance analytics and reporting                  │
│  matches            │  Match data and statistics                            │
│  schedules          │  Event and schedule management                        │
│  vod_reviews        │  Video review and timestamp management                │
│  team_goals         │  Goal setting and tracking                            │
│  riot_integration   │  Riot Games API integration                           │
│  competitive        │  PandaScore integration, pro matches, draft analysis  │
│  scrims             │  Scrim management and opponent team tracking          │
│  strategy           │  Draft planning and tactical board system             │
│  support            │  Support ticket system with staff dashboard and FAQ   │
└─────────────────────┴───────────────────────────────────────────────────────┘
```

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
            ChampionPoolModel[Champion Pool Model]
        end

        subgraph "Scouting Module"
            ScoutingController[Scouting Controller]
            ScoutingTargetModel[Scouting Target Model]
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
            PlayerMatchStatModel[Player Match Stat Model]
        end

        subgraph "Schedules Module"
            SchedulesController[Schedules Controller]
            ScheduleModel[Schedule Model]
        end

        subgraph "VOD Reviews Module"
            VODController[VOD Reviews Controller]
            VodReviewModel[VOD Review Model]
            VodTimestampModel[VOD Timestamp Model]
        end

        subgraph "Team Goals Module"
            GoalsController[Team Goals Controller]
            TeamGoalModel[Team Goal Model]
        end

        subgraph "Riot Integration Module"
            RiotService[Riot API Service]
            RiotSync[Sync Service]
        end

        subgraph "Competitive Module"
            CompetitiveController[Competitive Controller]
            ProMatchesController[Pro Matches Controller]
            PandaScoreService[PandaScore Service]
            DraftAnalyzer[Draft Analyzer]
        end

        subgraph "Scrims Module"
            ScrimsController[Scrims Controller]
            OpponentTeamsController[Opponent Teams Controller]
            ScrimAnalytics[Scrim Analytics Service]
        end

        subgraph "Strategy Module"
            DraftPlansController[Draft Plans Controller]
            TacticalBoardsController[Tactical Boards Controller]
            DraftAnalysisService[Draft Analysis Service]
        end

        subgraph "Support Module"
            SupportTicketsController[Support Tickets Controller]
            SupportFaqsController[Support FAQs Controller]
            SupportStaffController[Support Staff Controller]
            SupportTicketModel[Support Ticket Model]
            SupportFaqModel[Support FAQ Model]
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
        PandaScoreAPI[PandaScore API]
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
    Router --> CompetitiveController
    Router --> ProMatchesController
    Router --> ScrimsController
    Router --> OpponentTeamsController
    Router --> DraftPlansController
    Router --> TacticalBoardsController
    Router --> SupportTicketsController
    Router --> SupportFaqsController
    Router --> SupportStaffController
    AuthController --> JWTService
    AuthController --> UserModel
    PlayersController --> PlayerModel
    PlayerModel --> ChampionPoolModel
    ScoutingController --> ScoutingTargetModel
    ScoutingController --> Watchlist
    Watchlist --> PostgreSQL
    MatchesController --> MatchModel
    MatchModel --> PlayerMatchStatModel
    SchedulesController --> ScheduleModel
    VODController --> VodReviewModel
    VodReviewModel --> VodTimestampModel
    GoalsController --> TeamGoalModel
    AnalyticsController --> PerformanceService
    AnalyticsController --> KDAService
    CompetitiveController --> PandaScoreService
    CompetitiveController --> DraftAnalyzer
    ScrimsController --> ScrimAnalytics
    ScrimAnalytics --> PostgreSQL
    DraftPlansController --> DraftAnalysisService
    SupportTicketsController --> SupportTicketModel
    SupportFaqsController --> SupportFaqModel
    SupportStaffController --> UserModel
    AuditLogModel[AuditLog Model] --> PostgreSQL
    ChampionPoolModel[ChampionPool Model] --> PostgreSQL
    CompetitiveMatchModel[CompetitiveMatch Model] --> PostgreSQL
    DraftPlanModel[DraftPlan Model] --> PostgreSQL
    MatchModel[Match Model] --> PostgreSQL
    NotificationModel[Notification Model] --> PostgreSQL
    OpponentTeamModel[OpponentTeam Model] --> PostgreSQL
    OrganizationModel[Organization Model] --> PostgreSQL
    PasswordResetTokenModel[PasswordResetToken Model] --> PostgreSQL
    PlayerModel[Player Model] --> PostgreSQL
    PlayerMatchStatModel[PlayerMatchStat Model] --> PostgreSQL
    ScheduleModel[Schedule Model] --> PostgreSQL
    ScoutingTargetModel[ScoutingTarget Model] --> PostgreSQL
    ScrimModel[Scrim Model] --> PostgreSQL
    SupportFaqModel[SupportFaq Model] --> PostgreSQL
    SupportTicketModel[Support Ticket Model] --> PostgreSQL
    SupportTicketMessageModel[SupportTicketMessage Model] --> PostgreSQL
    TacticalBoardModel[TacticalBoard Model] --> PostgreSQL
    TeamGoalModel[Team Goal Model] --> PostgreSQL
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
    RiotService --> RiotSync
    RiotService --> RiotAPI

    RiotService --> Sidekiq
    PandaScoreService --> PandaScoreAPI
    Sidekiq -- Uses --> Redis

    style Client fill:#e1f5ff
    style PostgreSQL fill:#336791
    style Redis fill:#d82c20
    style RiotAPI fill:#eb0029
    style PandaScoreAPI fill:#ff6b35
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

---

## 04 · Setup

### Prerequisites

```
[✓] Ruby 3.2+
[✓] PostgreSQL 14+
[✓] Redis 6+
```

### Installation

**1. Clone the repository:**
```bash
git clone <repository-url>
cd prostaff-api
```

**2. Install dependencies:**
```bash
bundle install
```

**3. Setup environment variables:**
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
- Database credentials
- JWT secret key
- Riot API key (get from https://developer.riotgames.com)
- PandaScore API key (optional, for competitive data)
- Redis URL
- CORS origins
- HashID salt (for URL obfuscation — keep secret!)
- Frontend URL

**4. Setup the database:**
```bash
rails db:create
rails db:migrate
rails db:seed
```

**5. Start the services:**
```bash
# Terminal 1 — Redis
redis-server

# Terminal 2 — Sidekiq
bundle exec sidekiq

# Terminal 3 — Rails server
rails server
```

> API available at `http://localhost:3333`

---

## 05 · Development Tools

### Generate Secrets

Generate secure secrets for your `.env` file:

```bash
./scripts/generate_secrets.sh
```

Generates: `SECRET_KEY_BASE` (Rails) and `JWT_SECRET_KEY` (JWT signing).

### Get JWT Token (for API testing)

```bash
./scripts/get-token.sh
```

This will:
1. Create or find a test user (`test@prostaff.gg`)
2. Generate a valid JWT token
3. Show instructions on how to use it

**Quick usage:**
```bash
# Export to environment variable
export BEARER_TOKEN=$(./scripts/get-token.sh | grep -oP 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*')

# Use in curl
curl -H "Authorization: Bearer $BEARER_TOKEN" http://localhost:3333/api/v1/players
```

**Custom credentials:**
```bash
TEST_EMAIL="admin@example.com" TEST_PASSWORD="MyPass123!" ./scripts/get-token.sh
```

---

## 06 · API Documentation

<details>
<summary><kbd>▶ Interactive Documentation — Swagger UI (click to expand)</kbd></summary>

**Access:**
```
http://localhost:3333/api-docs
```

**Features:**
- Try out endpoints directly from the browser
- See request/response schemas
- Authentication support (Bearer token)
- Complete parameter documentation
- Example requests and responses

### Generating/Updating Documentation

```bash
# Run integration specs and generate Swagger docs
RSWAG_GENERATE=1 bundle exec rake rswag:specs:swaggerize

# Or run specs individually
bundle exec rspec spec/integration/
```

> **Note:** `RSWAG_GENERATE=1` bypasses the local test-DB requirement — the
> swagger formatter uses `--dry-run` so no database queries are executed.

Generated file: `swagger/v1/swagger.yaml`

### Base URL
```
http://localhost:3333/api/v1
```

### Authentication

All endpoints (except auth) require a Bearer token:

```
Authorization: Bearer <your-jwt-token>
```

```
╔═══════════════╦══════════════════════════════════╗
║  Token Type   ║  Bearer (JWT)                    ║
║  Access TTL   ║  24h (via JWT_EXPIRATION_HOURS)  ║
║  Refresh TTL  ║  7 days                          ║
╚═══════════════╩══════════════════════════════════╝
```

**Getting a token:**
```bash
# Option 1: Use the script
./scripts/get-token.sh

# Option 2: Login via API
curl -X POST http://localhost:3333/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@prostaff.gg","password":"Test123!@#"}'
```

**Refreshing a token:**
```bash
curl -X POST http://localhost:3333/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"your-refresh-token"}'
```

### Authentication Endpoints

- `POST /auth/register` — Register new organization and admin user
- `POST /auth/login` — Login user
- `POST /auth/refresh` — Refresh JWT token
- `POST /auth/logout` — Logout user
- `POST /auth/forgot-password` — Request password reset
- `POST /auth/reset-password` — Reset password
- `GET  /auth/me` — Get current user info

### Core Endpoints

#### Dashboard
- `GET /dashboard` — Get complete dashboard data
- `GET /dashboard/stats` — Get quick stats
- `GET /dashboard/activities` — Get recent activities
- `GET /dashboard/schedule` — Get upcoming schedule

#### Players
- `GET    /players` — List players
- `GET    /players/:id` — Get player details
- `POST   /players` — Create player
- `PATCH  /players/:id` — Update player
- `DELETE /players/:id` — Delete player
- `GET    /players/stats` — Get roster statistics
- `POST   /players/import` — Import player from Riot API

#### Matches
- `GET  /matches` — List matches
- `GET  /matches/:id` — Get match details
- `POST /matches` — Create match
- `POST /matches/import` — Import match from Riot API

#### Scouting
- `GET  /scouting/players` — List scouting targets
- `GET  /scouting/regions` — Get available regions
- `POST /scouting/players` — Add scouting target

#### Analytics
- `GET /analytics/performance` — Team performance analytics
- `GET /analytics/team-comparison` — Compare all players
- `GET /analytics/champions/:player_id` — Champion pool statistics
- `GET /analytics/kda-trend/:player_id` — KDA trend over time
- `GET /analytics/laning/:player_id` — Laning phase performance
- `GET /analytics/teamfights/:player_id` — Teamfight performance
- `GET /analytics/vision/:player_id` — Vision control statistics

#### Schedules
- `GET    /schedules` — List all scheduled events
- `GET    /schedules/:id` — Get schedule details
- `POST   /schedules` — Create new event
- `PATCH  /schedules/:id` — Update event
- `DELETE /schedules/:id` — Delete event

#### Team Goals
- `GET    /team-goals` — List all goals
- `GET    /team-goals/:id` — Get goal details
- `POST   /team-goals` — Create new goal
- `PATCH  /team-goals/:id` — Update goal progress
- `DELETE /team-goals/:id` — Delete goal

#### VOD Reviews
- `GET    /vod-reviews` — List VOD reviews
- `GET    /vod-reviews/:id` — Get review details
- `POST   /vod-reviews` — Create new review
- `PATCH  /vod-reviews/:id` — Update review
- `DELETE /vod-reviews/:id` — Delete review
- `GET    /vod-reviews/:id/timestamps` — List timestamps
- `POST   /vod-reviews/:id/timestamps` — Create timestamp
- `PATCH  /vod-timestamps/:id` — Update timestamp
- `DELETE /vod-timestamps/:id` — Delete timestamp

#### Riot Data
- `GET  /riot-data/champions` — Get champions ID map
- `GET  /riot-data/champions/:key` — Get champion details
- `GET  /riot-data/all-champions` — Get all champions data
- `GET  /riot-data/items` — Get all items
- `GET  /riot-data/summoner-spells` — Get summoner spells
- `GET  /riot-data/version` — Get current Data Dragon version
- `POST /riot-data/clear-cache` — Clear Data Dragon cache (owner only)
- `POST /riot-data/update-cache` — Update Data Dragon cache (owner only)

#### Riot Integration
- `GET /riot-integration/sync-status` — Get sync status for all players

#### Competitive (PandaScore Integration)
- `GET  /competitive-matches` — List competitive matches
- `GET  /competitive-matches/:id` — Get competitive match details
- `GET  /competitive/pro-matches` — List all pro matches
- `GET  /competitive/pro-matches/:id` — Get pro match details
- `GET  /competitive/pro-matches/upcoming` — Get upcoming pro matches
- `GET  /competitive/pro-matches/past` — Get past pro matches
- `POST /competitive/pro-matches/refresh` — Refresh pro matches from PandaScore
- `POST /competitive/pro-matches/import` — Import specific pro match
- `POST /competitive/draft-comparison` — Compare team compositions
- `GET  /competitive/meta/:role` — Get meta champions by role
- `GET  /competitive/composition-winrate` — Get composition winrate statistics
- `GET  /competitive/counters` — Get champion counter suggestions

#### Scrims Management
- `GET    /scrims/scrims` — List all scrims
- `GET    /scrims/scrims/:id` — Get scrim details
- `POST   /scrims/scrims` — Create new scrim
- `PATCH  /scrims/scrims/:id` — Update scrim
- `DELETE /scrims/scrims/:id` — Delete scrim
- `POST   /scrims/scrims/:id/add_game` — Add game to scrim
- `GET    /scrims/scrims/calendar` — Get scrims calendar
- `GET    /scrims/scrims/analytics` — Get scrims analytics
- `GET    /scrims/opponent-teams` — List opponent teams
- `GET    /scrims/opponent-teams/:id` — Get opponent team details
- `POST   /scrims/opponent-teams` — Create opponent team
- `PATCH  /scrims/opponent-teams/:id` — Update opponent team
- `DELETE /scrims/opponent-teams/:id` — Delete opponent team
- `GET    /scrims/opponent-teams/:id/scrim-history` — Get scrim history with opponent

#### Strategy Module
- `GET    /strategy/draft-plans` — List draft plans
- `GET    /strategy/draft-plans/:id` — Get draft plan details
- `POST   /strategy/draft-plans` — Create new draft plan
- `PATCH  /strategy/draft-plans/:id` — Update draft plan
- `DELETE /strategy/draft-plans/:id` — Delete draft plan
- `POST   /strategy/draft-plans/:id/analyze` — Analyze draft plan
- `PATCH  /strategy/draft-plans/:id/activate` — Activate draft plan
- `PATCH  /strategy/draft-plans/:id/deactivate` — Deactivate draft plan
- `GET    /strategy/tactical-boards` — List tactical boards
- `GET    /strategy/tactical-boards/:id` — Get tactical board details
- `POST   /strategy/tactical-boards` — Create new tactical board
- `PATCH  /strategy/tactical-boards/:id` — Update tactical board
- `DELETE /strategy/tactical-boards/:id` — Delete tactical board
- `GET    /strategy/tactical-boards/:id/statistics` — Get tactical board statistics
- `GET    /strategy/assets/champion/:champion_name` — Get champion assets
- `GET    /strategy/assets/map` — Get map assets

#### Support System
- `GET    /support/tickets` — List user's tickets
- `GET    /support/tickets/:id` — Get ticket details
- `POST   /support/tickets` — Create new support ticket
- `PATCH  /support/tickets/:id` — Update ticket
- `DELETE /support/tickets/:id` — Delete ticket
- `POST   /support/tickets/:id/close` — Close ticket
- `POST   /support/tickets/:id/reopen` — Reopen ticket
- `POST   /support/tickets/:id/messages` — Add message to ticket
- `GET    /support/faq` — List all FAQs
- `GET    /support/faq/:slug` — Get FAQ by slug
- `POST   /support/faq/:slug/helpful` — Mark FAQ as helpful
- `POST   /support/faq/:slug/not-helpful` — Mark FAQ as not helpful
- `GET    /support/staff/dashboard` — Support staff dashboard (staff only)
- `GET    /support/staff/analytics` — Support analytics (staff only)
- `POST   /support/staff/tickets/:id/assign` — Assign ticket to staff (staff only)
- `POST   /support/staff/tickets/:id/resolve` — Resolve ticket (staff only)

> For complete endpoint documentation with request/response examples, visit `/api-docs`

</details>

---

## 07 · Testing

### Unit & Request Tests

```bash
# Full test suite
bundle exec rspec

# Unit tests (models, services)
bundle exec rspec spec/models
bundle exec rspec spec/services

# Request tests (controllers)
bundle exec rspec spec/requests

# Integration tests (Swagger documentation)
bundle exec rspec spec/integration
```

### Integration Tests (Swagger Documentation)

Integration tests serve dual purpose:
1. **Test API endpoints** with real HTTP requests
2. **Generate Swagger documentation** automatically

```bash
# Run integration tests and generate Swagger docs
RSWAG_GENERATE=1 bundle exec rake rswag:specs:swaggerize

# Run specific integration spec
bundle exec rspec spec/integration/players_spec.rb
```

**Current coverage:**

```
╔══════════════════════════╦════════════════════╗
║  MODULE                  ║  ENDPOINTS         ║
╠══════════════════════════╬════════════════════╣
║  Authentication          ║  8                 ║
║  Players                 ║  9                 ║
║  Matches                 ║  11                ║
║  Scouting                ║  10                ║
║  Schedules               ║  8                 ║
║  Team Goals              ║  8                 ║
║  VOD Reviews             ║  11                ║
║  Analytics               ║  7                 ║
║  Riot Data               ║  14                ║
║  Riot Integration        ║  1                 ║
║  Dashboard               ║  4                 ║
║  Competitive             ║  14                ║
║  Scrims                  ║  14                ║
║  Strategy                ║  16                ║
║  Support                 ║  16                ║
║  Admin                   ║  9                 ║
║  Notifications           ║  6                 ║
║  Profile                 ║  4                 ║
║  Rosters                 ║  4                 ║
║  Team Members            ║  1                 ║
║  Messages                ║  2                 ║
║  Constants               ║  1                 ║
║  Fantasy                 ║  2                 ║
╠══════════════════════════╬════════════════════╣
║  TOTAL                   ║  200+ endpoints    ║
╚══════════════════════════╩════════════════════╝
```

### Code Coverage

```bash
open coverage/index.html
```

---

## 08 · Performance & Load Testing

### Load Testing (k6)

```bash
# Quick smoke test (1 min)
./load_tests/run-tests.sh smoke local

# Full load test (16 min)
./load_tests/run-tests.sh load local

# Stress test (28 min)
./load_tests/run-tests.sh stress local
```

```
╔═══════════════════════════════════════╗
║  PERFORMANCE BENCHMARKS               ║
╠══════════════════╦════════════════════╣
║  p(95) Docker    ║  ~880ms            ║
║  p(95) Prod est. ║  ~500ms            ║
║  With cache      ║  ~50ms             ║
║  Error rate      ║  0%                ║
╚══════════════════╩════════════════════╝
```

> See [TESTING_GUIDE.md](DOCS/tests/TESTING_GUIDE.md) and [QUICK_START.md](DOCS/setup/QUICK_START.md)

---

## 09 · Security Testing (OWASP)

```bash
# Complete security audit
./security_tests/scripts/full-security-audit.sh

# Individual scans
./security_tests/scripts/brakeman-scan.sh          # Code analysis
./security_tests/scripts/dependency-scan.sh        # Vulnerable gems
./security_tests/scripts/zap-baseline-scan.sh      # Web app scan
```

```
[✓] OWASP Top 10
[✓] Code security (Brakeman)
[✓] Dependency vulnerabilities
[✓] Runtime security (ZAP)
[✓] CI/CD integration
```

> See [security_tests/README.md](security_tests/README.md)

---

## 10 · Deployment

### Environment Variables

```bash
# Core
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://host:6379/0
SECRET_KEY_BASE=your-rails-secret

# Authentication
JWT_SECRET_KEY=your-production-secret

# External APIs
RIOT_API_KEY=your-riot-api-key
PANDASCORE_API_KEY=your-pandascore-api-key

# Frontend
CORS_ORIGINS=https://your-frontend-domain.com
FRONTEND_URL=https://your-frontend-domain.com

# HashID Configuration (for URL obfuscation)
HASHID_SALT=your-secret-salt
HASHID_MIN_LENGTH=6
```

### Docker

```bash
docker build -t prostaff-api .
docker run -p 3333:3000 prostaff-api
```

---

## 11 · CI/CD

### Architecture Diagram Auto-Update

```
┌────────────────────────────────────────────────────────────────┐
│  TRIGGER — changes in:                                         │
│    · app/modules/**    · app/models/**                         │
│    · app/controllers/**  · config/routes.rb  · Gemfile         │
├────────────────────────────────────────────────────────────────┤
│  PROCESS                                                       │
│    1. GitHub Actions detects relevant code changes             │
│    2. Runs scripts/update_architecture_diagram.rb              │
│    3. Script analyzes project structure                        │
│    4. Generates updated Mermaid diagram                        │
│    5. Updates README.md with new diagram                       │
│    6. Commits changes back to the repository                   │
└────────────────────────────────────────────────────────────────┘
```

**Manual update:**
```bash
ruby scripts/update_architecture_diagram.rb
```

### CI/CD Workflows

Automated testing on every push:
- **Security Scan**: Brakeman + dependency check
- **Load Test**: Nightly smoke tests
- **Nightly Audit**: Complete security scan

See `.github/workflows/` for details.

---

## 12 · Contributing

1. Create a feature branch
2. Make your changes
3. Add tests
4. Run security scan: `./security_tests/scripts/brakeman-scan.sh`
5. Ensure all tests pass
6. Submit a pull request

> The architecture diagram will be automatically updated when you add new modules, models, or controllers.

---

## 13 · License

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  © 2026 ProStaff.gg. All rights reserved.                                    ║
║                                                                              ║
║  This repository contains the official ProStaff.gg API source code.          ║
║  Released under:                                                             ║
║                                                                              ║
║  Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International     ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

[![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

---

## Disclaimer

> Prostaff.gg isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties.
>
> Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.

---

<div align="center">

```
▓▒░ · © 2026 PROSTAFF.GG · ░▒▓
```

</div>
