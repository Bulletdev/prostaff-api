
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
│  [■] Meta Intelligence        — Build aggregation, champion/item analytics  │
│  [■] Support System           — Ticketing + staff dashboard + FAQ           │
│  [■] Global Search            — Meilisearch full-text search across models  │
│  [■] Real-time Messaging      — Action Cable WebSocket team chat            │
│  [■] Background Jobs          — Sidekiq for async background processing     │
│  [■] Security Hardened        — OWASP Top 10, Brakeman, ZAP tested          │
│  [■] High Performance         — p95: ~500ms · cached: ~50ms                 │
│  [■] Modular Monolith         — Scalable modular architecture               │
│  [■] Observability            — /health/live + /health/ready + Sidekiq mon. │
│  [■] 401 Rate Spike Detection — Sliding-window middleware, alerts at >5%    │
│  [■] Job Heartbeat Tracking   — Stale scheduled job detection via Redis     │
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
│  10 · Observability & Monitoring                     │
│  11 · Deployment                                     │
│  12 · CI/CD                                          │
│  13 · Contributing                                   │
│  14 · License                                        │
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
║  LAYER               ║  TECNOLOGY                                         ║
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
║  Full-text Search    ║  Meilisearch                                       ║
║  Real-time           ║  Action Cable (WebSocket)                          ║
╚══════════════════════╩════════════════════════════════════════════════════╝
```

---

## 03 · Architecture

This API follows a **modular monolith** architecture:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  MODULE             │  RESPONSIBILITY                                       │
├─────────────────────┼───────────────────────────────────────────────────────┤
│  core               │  Shared base classes, concerns and constants          │
│  authentication     │  User auth and authorization                          │
│  admin              │  Organization, audit log and admin player management  │
│  dashboard          │  Dashboard statistics and metrics                     │
│  players            │  Player management, rosters and statistics            │
│  scouting           │  Player scouting and talent discovery                 │
│  analytics          │  Performance, competitive draft, tournament & opponent│
│  matches            │  Match data and statistics                            │
│  schedules          │  Event and schedule management                        │
│  vod_reviews        │  Video review and timestamp management                │
│  team_goals         │  Goal setting and tracking                            │
│  riot_integration   │  Riot Games API integration                           │
│  competitive        │  PandaScore integration, pro matches, draft analysis  │
│  meta_intelligence  │  Build aggregation, champion/item meta analytics      │
│  scrims             │  Scrim management and opponent team tracking          │
│  strategy           │  Draft planning and tactical board system             │
│  support            │  Support ticket system with staff dashboard and FAQ   │
│  messaging          │  Real-time team chat via Action Cable WebSocket       │
│  search             │  Global full-text search powered by Meilisearch       │
│  notifications      │  In-app notification system                           │
└─────────────────────┴───────────────────────────────────────────────────────┘
```

### Architecture

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
- `competitive` - PandaScore integration, pro matches, draft analysis
- `scrims` - Scrim management and opponent team tracking
- `strategy` - Draft planning and tactical board system
- `support` - Support ticket system with staff and FAQ management

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

        subgraph "Analytics Module"
            AnalyticsController[Analytics Controller]
            PerformanceService[Performance Service]
            KDAService[KDA Trend Service]
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
    
    Router --> AnalyticsController
    Router --> CompetitiveController
    Router --> ProMatchesController
    Router --> ScrimsController
    Router --> OpponentTeamsController
    AuthController --> JWTService
    AuthController --> UserModel
    AnalyticsController --> PerformanceService
    AnalyticsController --> KDAService
    CompetitiveController --> PandaScoreService
    CompetitiveController --> DraftAnalyzer
    ScrimsController --> ScrimAnalytics
    ScrimAnalytics --> PostgreSQL
    AuditLogModel[AuditLog Model] --> PostgreSQL
    CurrentModel[Current Model] --> PostgreSQL
    OrganizationModel[Organization Model] --> PostgreSQL
    PasswordResetTokenModel[PasswordResetToken Model] --> PostgreSQL
    TokenBlacklistModel[TokenBlacklist Model] --> PostgreSQL
    UserModel[User Model] --> PostgreSQL
    JWTService --> Redis
    DashStats --> Redis
    PerformanceService --> Redis
    PlayersController --> RiotService
    MatchesController --> RiotService
    ScoutingController --> RiotService
    RiotService --> RiotSync
    RiotService --> RiotAPI

    RiotService --> Sidekiq
    PandaScoreService --> PandaScoreAPI[PandaScore API]
    Sidekiq -- Uses --> Redis
    
    style Client fill:#e1f5ff
    style PostgreSQL fill:#336791
    style Redis fill:#d82c20
    style RiotAPI fill:#eb0029
    style PandaScoreAPI fill:#ff6b35
    style Sidekiq fill:#b1003e
```


> ** Better Visualization Options:**
>
> The diagram above may be difficult to read in GitHub's preview. For better visualization:
> - **[View in Mermaid Live Editor](https://mermaid.live/)** - Open `diagram.mmd` file in the live editor
> - **[View in VS Code](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid)** - Install Mermaid extension
> - **Export diagram**: Use the standalone `diagram.mmd` file for import into diagramming tools
>
> The complete Mermaid source is available in [`diagram.mmd`](./diagram.mmd).

**Key Architecture Principles:**

1. **Modular Monolith**: Each module is self-contained with its own controllers, models, and services
2. **API-Only**: Rails configured in API mode for JSON responses
3. **JWT Authentication**: Stateless authentication using JWT tokens
4. **Background Processing**: Long-running tasks handled by Sidekiq
5. **Caching**: Redis used for session management and performance optimization
6. **External Integration**: Riot Games API integration for real-time data
7. **Rate Limiting**: Rack::Attack for API rate limiting
8. **CORS**: Configured for cross-origin requests from frontend

## 04 · Setup

### Prerequisites

```
[✓] Ruby 3.4.5+
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
- `GET /analytics/competitive/draft-performance` — Pick/ban/side/role performance from competitive matches
- `GET /analytics/competitive/tournament-stats` — Win/loss breakdown per tournament and stage
- `GET /analytics/competitive/opponents` — Aggregated record against each unique opponent

> All competitive analytics endpoints accept optional query filters: `tournament`, `patch`, `region`, `start_date`, `end_date`

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

#### Meta Intelligence
- `GET  /meta/builds` — List aggregated champion builds
- `GET  /meta/builds/:champion` — Get build stats for a specific champion
- `POST /meta/builds/aggregate` — Trigger build aggregation job (admin)
- `GET  /meta/items` — List item analytics
- `GET  /meta/items/:item_id` — Get item performance stats

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

#### Global Search
- `GET /search?q=:query` — Full-text search across players, organizations, scouting targets, opponent teams and FAQs

#### Notifications
- `GET    /notifications` — List user notifications
- `GET    /notifications/:id` — Get notification
- `PATCH  /notifications/:id/mark-as-read` — Mark as read
- `PATCH  /notifications/mark-all-as-read` — Mark all as read
- `GET    /notifications/unread-count` — Get unread count
- `DELETE /notifications/:id` — Delete notification

#### Health & Observability

```
GET /health/live              — Liveness probe: is Puma alive? Never checks deps.
                                Always returns 200 while the process responds.
                                Use for container restart policies (Coolify/K8s).

GET /health/ready             — Readiness probe: checks PostgreSQL + Redis + Meilisearch.
                                Returns 200 (ok/disabled) or 503 (any dep unreachable).
                                Use for load balancer traffic routing.

GET /api/v1/monitoring/sidekiq  — Admin only. Full Sidekiq snapshot:
                                  queue depths, worker count, dead queue, retry queue,
                                  scheduled job heartbeats (stale detection), alert flags.
                                  Returns 503 if Redis unavailable.
```

> **Monitoring endpoint response includes:**
> - `scheduled_jobs` — last run timestamp + `stale: true/false` per cron job
> - `alerts.stale_jobs` — true if any scheduled job exceeded its alert window
> - `alerts.no_workers` — true if no Sidekiq workers running
> - `alerts.dead_queue_exceeded` — true if dead queue > 10 jobs
> - `alerts.queue_depth_exceeded` — true if total queue depth > 100 jobs

#### Team Members (chat)
- `GET /team-members` — List organization members (staff only — rejects player tokens)

#### Messages (DM)
- `GET    /messages` — List direct message history with a member
- `DELETE /messages/:id` — Soft-delete a message

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
║  Meta Intelligence       ║  5                 ║
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

## 09 · Security

### Security Testing (OWASP)

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

### Security Status

**Last Audit**: 2026-03-04
**Overall Grade**: A (26/27 tests passed - 96%)
**Status**: Production-ready

### Reporting Vulnerabilities

We take security seriously. If you discover a security vulnerability, please follow our [Security Policy](SECURITY.md).

**DO NOT** create public GitHub issues for security vulnerabilities.

**Email**: security@prostaff.gg

### Security Resources

- [Security Policy](SECURITY.md) - Vulnerability disclosure process
- [Security Test Results](.pentest/SECURITY-TEST-RESULTS.md) - Latest audit results
- [Security Testing Guide](security_tests/README.md) - Running security tests
- [CI/CD Security Workflow](.github/workflows/README.md) - Automated security scanning

---

## 10 · Observability & Monitoring

### Health Probes

| Endpoint | Purpose | Returns |
|---|---|---|
| `GET /health/live` | Liveness — is Puma responding? | Always 200 |
| `GET /health/ready` | Readiness — all deps reachable? | 200 / 503 |
| `GET /up` | Legacy backward-compatible alias | 200 |

> **Rule**: never point the liveness probe at an endpoint that checks Redis or DB.
> A Redis crash → liveness fail → container restart → reconnect storm → worse incident.

### Sidekiq Monitoring

```bash
# Requires admin Bearer token
curl -H "Authorization: Bearer $TOKEN" https://api.prostaff.gg/api/v1/monitoring/sidekiq
```

Response shape:
```json
{
  "status": "ok | degraded | critical",
  "processes": { "count": 1, "workers": [...] },
  "queues": { "default": 0, "high": 0 },
  "stats": { "enqueued": 0, "dead": 0, "retry": 0 },
  "scheduled_jobs": {
    "RefreshMetadataViewsJob": { "last_run_at": "...", "stale": false },
    "CleanupExpiredTokensJob":  { "last_run_at": "...", "stale": false }
  },
  "alerts": {
    "no_workers": false,
    "queue_depth_exceeded": false,
    "dead_queue_exceeded": false,
    "stale_jobs": false
  }
}
```

**Status rules:**

| status                 |                   condition                        |
|------------------------|----------------------------------------------------|
| `ok`                   | all thresholds within bounds                       |
| `degraded`             | queue > 100, dead > 10, or any scheduled job stale |
| `critical`             | no Sidekiq workers running                         |

### 401 Rate Spike Detection

`Middleware::AuthFailureTracker` counts 401s vs total requests using Redis
sliding-window counters (5-minute window). Emits a structured log alert when
the ratio exceeds 5%:

```json
{
  "event": "auth_spike_detected",
  "level": "CRITICAL",
  "rate_pct": 8.3,
  "threshold_pct": 5.0,
  "total_requests": 240,
  "total_401s": 20
}
```

Threshold and window are configurable via env:

```bash
AUTH_TRACKER_THRESHOLD=0.05   # default: 5%
AUTH_TRACKER_WINDOW=5         # default: 5 minutes
```

### Configurable Alert Thresholds

```bash
SIDEKIQ_QUEUE_ALERT_THRESHOLD=100   # queue depth that triggers degraded
SIDEKIQ_DEAD_ALERT_THRESHOLD=10     # dead queue size that triggers degraded
```

---

## 11 · Deployment

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

# Observability thresholds (optional, defaults shown)
SIDEKIQ_QUEUE_ALERT_THRESHOLD=100   # queue depth → degraded
SIDEKIQ_DEAD_ALERT_THRESHOLD=10     # dead queue   → degraded
AUTH_TRACKER_THRESHOLD=0.05         # 401 rate spike threshold (5%)
AUTH_TRACKER_WINDOW=5               # sliding window in minutes
```

### Docker

```bash
docker build -t prostaff-api .
docker run -p 3333:3000 prostaff-api
```

---

## 12 · CI/CD

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
- **CORS Smoke Test**: Runs after every production deploy — sends a preflight request from each allowed origin and fails the pipeline if CORS is misconfigured

See `.github/workflows/` for details.

---

## 13 · Contributing

We welcome contributions from the community! Before contributing, please read our guidelines.

### Quick Start for Contributors

1. Read the [Contributing Guidelines](CONTRIBUTING.md)
2. Review the [Code of Conduct](CODE_OF_CONDUCT.md)
3. Fork the repository
4. Create a feature branch
5. Make your changes following our code style
6. Add tests for new functionality
7. Run security scans: `./security_tests/scripts/brakeman-scan.sh`
8. Ensure all tests pass: `bundle exec rspec`
9. Submit a pull request

### Branch Naming

- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation changes
- `security/` - Security fixes

### Code Style

We follow [Ruby Style Guide](https://rubystyle.guide/) and enforce code quality standards:

- Cyclomatic complexity ≤ 7
- Method length ≤ 50 lines
- All queries must be scoped by organization (multi-tenant!)
- Run Brakeman before committing (no HIGH/CRITICAL issues)

### Resources for Contributors

- [Contributing Guidelines](CONTRIBUTING.md) - Detailed contribution process
- [Code of Conduct](CODE_OF_CONDUCT.md) - Community standards
- [Security Policy](SECURITY.md) - Reporting security vulnerabilities
- [Testing Guide](DOCS/tests/TESTING_GUIDE.md) - How to run tests
- [Quick Start](DOCS/setup/QUICK_START.md) - Development environment setup

> **Note**: The architecture diagram will be automatically updated when you add new modules, models, or controllers.

---

## 14 · License

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
