
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
  
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/30bf4e093ece4ceb8ea46dbe7aecdee1)](https://app.codacy.com/gh/Bulletdev/prostaff-api/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2FBulletdev%2Fprostaff-api.svg?type=shield&issueType=license)](https://app.fossa.com/projects/git%2Bgithub.com%2FBulletdev%2Fprostaff-api?ref=badge_shield&issueType=license)

[![Snyk Container Scan](https://img.shields.io/github/actions/workflow/status/Bulletdev/prostaff-api/snyk-container.yml?style=plastic&logo=snyk&logoColor=4B45A1&labelColor=white&label=Snyk)](https://github.com/Bulletdev/prostaff-api/actions/workflows/snyk-container.yml)
[![Security Scan](https://github.com/Bulletdev/prostaff-api/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Bulletdev/prostaff-api/actions/workflows/security-scan.yml)
[![CodeQL](https://github.com/Bulletdev/prostaff-api/actions/workflows/codeql.yml/badge.svg)](https://github.com/Bulletdev/prostaff-api/actions/workflows/codeql.yml)


[![Ruby Version](https://img.shields.io/badge/ruby-3.4.8-CC342D?logo=ruby)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-7.2.3.1-CC342D?logo=rubyonrails)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue.svg?logo=postgresql)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-6+-red.svg?logo=redis)](https://redis.io/)
[![Swagger](https://img.shields.io/badge/API-Swagger-85EA2D?logo=swagger)](http://localhost:3333/api-docs)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

</div>

---

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PROSTAFF API — Ruby on Rails 7.2 (API-Only)                                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Backend for the ProStaff.gg esports team management platform.               ║
║  200+ documented endpoints · JWT Auth · Modular Monolith · p95 ~200ms        ║
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
│  [■] Competitive Module       — PandaScore + ES match detail + H2H          │
│  [■] Match Detail View        — Per-game picks, KDA, gold, CS, DMG from ES  │
│  [■] Pro Match Data Lake      — 97K+ games (2014-2026) in Elasticsearch     │
│  [■] Multi-League Backfill    — CBLOL · Academy · CD auto-sync daily        │
│  [■] Scrims Management        — Opponent tracking + analytics               │
│  [■] Strategy Module          — Draft planning + tactical boards            │
│  [■] AI Pick Recommendations  — Champion2Vec + XGBoost, 97K+ game dataset   │
│  [■] Meta Intelligence        — Build aggregation, champion/item analytics  │
│  [■] Support System           — Ticketing + staff dashboard + FAQ           │
│  [■] Global Search            — Meilisearch full-text search across models  │
│  [■] Search Fallback          — PostgreSQL ILIKE fallback when Meili offline│
│  [■] Real-time Messaging      — Action Cable WebSocket team chat            │
│  [■] Background Jobs          — Sidekiq for async background processing     │
│  [■] Circuit Breaker          — Riot API isolation (3-state, Redis-backed)  │
│  [■] Async Audit Log          — Non-blocking audit trail via Sidekiq job    │
│  [■] Response Cache Layer     — Redis cache on 6 endpoints (TTL 5–30 min)   │
│  [■] Security Hardened        — OWASP Top 10, Brakeman, Semgrep, CodeQL, ZAP│
│  [■] Rate Limiting            — Rack::Attack: 5 rules + Retry-After headers │
│  [■] High Performance         — p95: ~200ms prod · cached: ~50ms · >60% hit │
│  [■] Modular Monolith         — Scalable modular architecture               │
│  [■] Observability            — /health+/live /health/ready + cache metrics │
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
│  12 · CI/CD & CodeQL                                 │
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
║  Language            ║  Ruby 3.4.8                                        ║
║  Framework           ║  Rails 7.2.3.1 (API-only mode)                     ║
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
║  Data Lake           ║  Elasticsearch 8 (97K+ pro games, all leagues)     ║
║  ML Service          ║  Python 3.11 · FastAPI · XGBoost · Gensim Word2Vec ║
╚══════════════════════╩════════════════════════════════════════════════════╝
```

---


## 03 · Architecture

This API follows a **modular monolith** architecture with the following modules:

<details>
<summary><kbd>▶ See details (click to expand)</kbd></summary>


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
│  competitive        │  PandaScore/Grid.gg + Elasticsearch match detail/Draft│
│  meta_intelligence  │  Build aggregation, champion/item meta analytics      │
│  scrims             │  Scrim management and opponent team tracking          │
│  strategy           │  Draft planning and tactical board system             │
│  ai_intelligence    │  Champion2Vec embeddings, win probability, ML picks   │
│  support            │  Support ticket system with staff dashboard and FAQ   │
│  messaging          │  Real-time team chat via Action Cable WebSocket       │
│  search             │  Global full-text search powered by Meilisearch       │
│  notifications      │  In-app notification system                           │
│  tournaments        │  ArenaBR double-elimination tournament management     │
└─────────────────────┴───────────────────────────────────────────────────────┘
```
</details>

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
- `competitive` - PandaScore & Grid.gg integration, pro matches, draft analysis
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
[✓] Ruby 3.4.8+
[✓] PostgreSQL 14+
[✓] Redis 6+
```

<details>
<summary><kbd>▶ Installation (click to expand)</kbd></summary>

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
</details>


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

#### Competitive (PandaScore + Elasticsearch)
- `GET  /competitive-matches` — List competitive matches
- `GET  /competitive-matches/:id` — Get competitive match details
- `GET  /competitive/pro-matches` — List all pro matches
- `GET  /competitive/pro-matches/:id` — Get pro match details
- `GET  /competitive/pro-matches/upcoming` — Get upcoming pro matches
- `GET  /competitive/pro-matches/past` — Get past pro matches
- `POST /competitive/pro-matches/refresh` — Refresh pro matches from PandaScore
- `POST /competitive/pro-matches/import` — Import specific pro match
- `GET  /competitive/pro-matches/match-preview` — Per-game picks + stats for a recent series (ES)
- `GET  /competitive/pro-matches/es-series` — H2H series history between two teams (ES)
- `POST /competitive/draft-comparison` — Compare team compositions
- `GET  /competitive/meta/:role` — Get meta champions by role
- `GET  /competitive/composition-winrate` — Get composition winrate statistics
- `GET  /competitive/counters` — Get champion counter suggestions

> `match-preview` and `es-series` query the Elasticsearch data lake (97K+ games) and are league-agnostic. They accept `?team1=&team2=&league=&limit=` query params.

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

#### AI Intelligence

> Requires Tier 1 (Professional) subscription — `predictive_analytics` feature gate.

- `POST /ai/draft/analyze` — Analyze a saved draft plan (synergy, counter, risk, readiness)
- `POST /ai/recommend-pick` — Top-5 ML champion recommendations for a partial draft

**Request** (`/ai/recommend-pick`):
```json
{
  "our_picks":      ["Jinx", "Thresh", "Azir"],
  "opponent_picks": ["Caitlyn", "Nautilus", "Syndra", "Renekton", "Graves"],
  "our_bans":       ["Corki"],
  "opponent_bans":  ["Zeri"],
  "patch":          "16.08",
  "league":         "LCK"
}
```

**Response**:
```json
{
  "data": {
    "source": "ml_v2",
    "model_version": "v2",
    "recommendations": [
      {
        "champion": "Lissandra",
        "score": 0.5219,
        "win_probability": 0.553,
        "synergy_score": 0.3557,
        "counter_score": 0.3252,
        "reasoning_tokens": ["high win probability (55%)", "decent synergy with current picks"]
      }
    ]
  }
}
```

Response header `X-AI-Source: ml_v2` (XGBoost) or `X-AI-Source: legacy` (DraftSuggester fallback when ML service is unreachable).

The ML service (`prostaff-ml`) is a FastAPI container trained on 97K+ competitive matches using Champion2Vec embeddings (64D, Gensim Word2Vec) and an XGBoost classifier with 327 features. Training pipeline: `extract_features → train_champion2vec → train_win_probability → validate → export`. See [`prostaff-ml`](https://github.com/bulletdev/prostaff-ml).

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

#### Tournaments (ArenaBR)
- `GET    /tournaments` — List active tournaments (public)
- `GET    /tournaments/:id` — Show tournament with full bracket (public)
- `POST   /tournaments` — Create tournament (admin only)
- `PATCH  /tournaments/:id` — Update tournament (admin only)
- `POST   /tournaments/:id/generate_bracket` — Generate 16-team double-elimination bracket (admin only)
- `GET    /tournaments/:id/teams` — List enrolled teams with roster snapshot (public)
- `POST   /tournaments/:id/teams` — Enroll organization as team
- `PATCH  /tournaments/:id/teams/:team_id/approve` — Approve enrollment + lock roster (admin only)
- `PATCH  /tournaments/:id/teams/:team_id/reject` — Reject enrollment (admin only)
- `DELETE /tournaments/:id/teams/:team_id` — Withdraw team (own org, before bracket)
- `GET    /tournaments/:id/matches` — List all bracket matches (public)
- `GET    /tournaments/:id/matches/:match_id` — Show match detail with checkin status
- `POST   /tournaments/:id/matches/:match_id/checkin` — Captain confirms presence
- `GET    /tournaments/:id/matches/:match_id/report` — Get report status
- `POST   /tournaments/:id/matches/:match_id/report` — Submit result report with evidence
- `POST   /tournaments/:id/matches/:match_id/report/admin_resolve` — Admin resolves dispute (admin only)

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

GET /api/v1/monitoring/sidekiq      — Admin only. Full Sidekiq snapshot:
                                      queue depths, worker count, dead queue, retry queue,
                                      scheduled job heartbeats (stale detection), alert flags.
                                      Returns 503 if Redis unavailable.

GET /api/v1/monitoring/cache_stats  — Admin only. Real-time cache hit rate:
                                      total reads, hits, misses, hit_rate (%).
                                      Counters persist in Redis, reset on Redis flush.
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
║  p(95) Prod est. ║  <200ms(target)    ║
║  With cache      ║  ~50ms             ║
║  Cache hit rate  ║  >60%(after warmup)║
║  Error rate      ║  0%                ║
╚══════════════════╩════════════════════╝
```

**Cached endpoints** (Redis, org-scoped, bypass on filter params):

| Endpoint | TTL | Invalidation |
|---|---|---|
| `GET /players` | 5 min | `after_commit` on Player |
| `GET /players/:id` | 5 min | After Riot sync |
| `GET /matches` | 5 min | `after_commit` on Match |
| `GET /analytics/performance` | 15 min | After Match sync |
| `GET /tournaments` | 30 min | `after_commit` on Tournament |

All cached responses include `X-Cache-Hit: true/false` header.

> See [TESTING_GUIDE.md](DOCS/tests/TESTING_GUIDE.md) and [QUICK_START.md](DOCS/setup/QUICK_START.md)

---

## 09 · Security

### Security Testing

```bash
# Complete security audit
./security_tests/scripts/full-security-audit.sh

# SAST — code + dependency analysis
./security_tests/scripts/brakeman-scan.sh          # Rails-specific SAST
./security_tests/scripts/dependency-scan.sh        # Vulnerable gems (bundle-audit)

# DAST — runtime scanning
./security_tests/scripts/zap-baseline-scan.sh      # OWASP ZAP baseline
./security_tests/scripts/zap-api-scan.sh           # ZAP API scan (OpenAPI)

# Application-specific tests
./security_tests/scripts/test-multi-tenancy-isolation.sh  # cross-org data leakage
./security_tests/scripts/test-ssrf-protection.sh          # SSRF in Riot API URLs
./security_tests/scripts/test-rate-limiting.sh            # Rack::Attack throttle rules
./security_tests/scripts/test-timing-oracle.sh            # user enumeration via timing
./security_tests/scripts/test-body-fuzzing.sh             # mass assignment + type confusion
```

```
[✓] OWASP Top 10
[✓] SAST: Brakeman (Rails) + Semgrep + CodeQL (security-extended)
[✓] Dependency audit: bundle-audit + FOSSA
[✓] Secrets: TruffleHog (verified secrets, full git history)
[✓] DAST: OWASP ZAP baseline + API scan
[✓] Multi-tenancy isolation (cross-org IDOR)
[✓] Rate limiting: Rack::Attack rules validated (5 throttle rules)
[✓] Timing oracle: login/register user enumeration
[✓] Mass assignment: StrongParameters coverage
[✓] CI/CD: security gates on every push + weekly CodeQL
```

### Security Status

**Last Audit**: 2026-04-21
**Overall Grade**: A (all application security tests passing)
**Status**: Production-ready

### Rate Limiting (Rack::Attack)

|            Rule         |              Limit          |          Window       |
|-------------------------|-----------------------------|-----------------------|
| `logins/ip`             |             5 requests      |       20 seconds      |
| `register/ip`           |             3 requests      |        1 hour         |
| `password_reset/ip`     |          5 requests         |        1 hour         |
| `req/ip`                | 300 requests (configurable) |       per period      |
| `req/authenticated_user`|          1000 requests      |        1 hour         |

All 429 responses include a `Retry-After` header with the exact seconds until the window resets.

### Reporting Vulnerabilities

We take security seriously. If you discover a security vulnerability, please follow our [Security Policy](SECURITY.md).

**DO NOT** create public GitHub issues for security vulnerabilities.

**Email**: security@prostaff.gg

### Security Resources

- [Security Policy](SECURITY.md) - Vulnerability disclosure process
- [Security Testing Guide](security_tests/README.md) - Running security tests

---

## 10 · Observability & Monitoring
<details>
<summary><kbd>▶ for details (click to expand)</kbd></summary>

### Health Probes

|       Endpoint      |             Purpose              |   Returns  |
|---------------------|----------------------------------|------------|
| `GET /health/live`  | Liveness — is Puma responding?   | Always 200 |
| `GET /health/ready` | Readiness — all deps reachable?  | 200 / 503  |
| `GET /up`           | Legacy backward-compatible alias |    200     |

> **Rule**: never point the liveness probe at an endpoint that checks Redis or DB.
> A Redis crash → liveness fail → container restart → reconnect storm → worse incident.

### Sidekiq Monitoring

```bash
# Requires admin Bearer token
curl -H "Authorization: Bearer $TOKEN" https://api.prostaff.gg/api/v1/monitoring/sidekiq

# Cache hit rate
curl -H "Authorization: Bearer $TOKEN" https://api.prostaff.gg/api/v1/monitoring/cache_stats
# { "reads": 4200, "hits": 2730, "misses": 1470, "hit_rate": "65.0%" }
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

### Circuit Breaker — Riot API

`CircuitBreakerService` protects the Riot API integration from cascade failures.
State persists in Redis (shared across all Puma workers and Sidekiq threads).

```
closed  (normal)    — requests pass through; failure count incremented on error
open    (tripped)   — requests rejected immediately (<100ms); no upstream call
half-open (recovery)— one probe request allowed; success closes, failure re-opens
```

|     Parameter     |        Default       |           Env override      |
|-------------------|----------------------|-----------------------------|
| Failure threshold | 5 consecutive errors | `CIRCUIT_BREAKER_THRESHOLD` |
| Recovery timeout  | 60 seconds           |                —            |

Log events emitted on state transitions:
```
[CIRCUIT_BREAKER] Circuit riot_api OPENED after 5 consecutive failures
[CIRCUIT_BREAKER] Circuit riot_api CLOSED after recovery
```

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
</details>

---

## 11 · Deployment

### Ecosystem

This API is one service in the ProStaff ecosystem. The other services it integrates with:

|                    Service                          |      Stack       |                          Role                                                                             |
|-----------------------------------------------------|------------------|-----------------------------------------------------------------------------------------------------------|
| [prostaff-events](https://github.com/bulletdev/prostaff-events)        | Elixir / Phoenix 1.7  | Real-time event bus — subscribes to Redis pub/sub and pushes via Phoenix Channels |
| [prostaff-riot-gateway](https://github.com/bulletdev/prostaff-gateway) | Go 1.23               | Riot API proxy — token bucket rate limiting, L1/L2 cache, circuit breaker         |
| [ProStaff-Scraper](https://github.com/bulletdev/ProStaff-Scraper)      | Python / FastAPI      | Pro match data pipeline — Leaguepedia + Oracle's Elixir → Elasticsearch           |
|🔒prostaff-ml                 | Python 3.11 / FastAPI | ML service — Champion2Vec + XGBoost pick recommendations (serves `POST /ai/recommend-pick`) |
|🔒prostaff-analytics-hub  | Next.js 15 / vinext    | Frontend SPA — consumes API (also: https://prostaff.gg, https://scrims.lol)

### Deployment Architecture

```mermaid

graph TB
    subgraph "Clients"
        FrontendApp["ProStaff.gg<br/>Front + TypeScript SPA"]
        PlayerPortal["Player Portal<br/>JWT player token"]
    end

    subgraph "Production — Coolify"
        Traefik["Traefik<br/>TLS + Let's Encrypt<br/>WebSocket proxy"]
        CoolifyNode["Coolify<br/>Deploys & Manages<br/>all production services"]
    end

    subgraph "Rails — Puma"
        Cable["Action Cable<br/>WSS /cable<br/>(team chat)"]
        Router["Rails Router<br/>REST API v1<br/>200+ endpoints"]
        Sidekiq["Sidekiq<br/>Background Workers<br/>(sync + backfill)"]
    end

    subgraph "prostaff-events — Elixir/Phoenix"
        PhoenixEndpoint["Phoenix Endpoint<br/>WSS /socket<br/>(domain events)"]
        RedisSub["RedisSubscriber<br/>PSUBSCRIBE prostaff:events:*"]
        InhouseQ["InhouseQueue<br/>GenServer per active queue"]
    end

    subgraph "prostaff-riot-gateway — Go"
        Gateway["Riot Gateway :4444<br/>Token bucket · L1/L2 cache<br/>Circuit breaker"]
    end

    subgraph "prostaff-ml — Python/FastAPI"
        MlService["ML Service :8001<br/>Champion2Vec + XGBoost<br/>POST /recommend · /win-probability"]
        MlModels[("Models<br/>champion2vec.bin<br/>win_probability_v2.pkl")]
    end

    subgraph "prostaff-scraper — Python/FastAPI"
        ScraperApi["Scraper API :8000<br/>GET /health · /matches · /status"]
        ScraperCron["scraper-cron<br/>polls LoL Esports API<br/>(every SYNC_INTERVAL_HOURS)"]
        Enrichment["enrichment daemon<br/>Leaguepedia + Riot<br/>(items/runes/KDA)"]
        Backfill["backfill daemon<br/>historical Leaguepedia<br/>(2013 → present)"]
    end

    subgraph "Data"
        PG[("PostgreSQL")]
        RD[("Redis")]
        Meili[("Meilisearch")]
        ES[("Elasticsearch\n97K+ pro games")]
    end

    subgraph "External APIs"
        RiotAPI["Riot Games API"]
        PandaScore["PandaScore API"]
        Grid.gg["Grid.gg"]
        LoLEsports["LoL Esports API"]
        Leaguepedia["Leaguepedia<br/>(lol.fandom.com)"]
    end

    %% === Conexões ===
    FrontendApp -- "HTTPS REST" --> Traefik
    FrontendApp -- "WSS /cable" --> Traefik
    FrontendApp -- "WSS /socket" --> Traefik
    PlayerPortal -- "HTTPS REST" --> Traefik

    Traefik -- "HTTP" --> Router
    Traefik -- "WS upgrade /cable" --> Cable
    Traefik -- "WS upgrade /socket" --> PhoenixEndpoint

    Router -- "reads / writes" --> PG
    Router -- "cache · JWT blacklist" --> RD
    Router -- "full-text search" --> Meili
    Router -- "publish prostaff:events:*" --> RD
    Router -- "match detail · H2H" --> ES
    Router -. "internal JWT<br/>(internal only)" .-> Gateway

    Cable -- "pub/sub" --> RD

    Sidekiq -- "async jobs" --> PG
    Sidekiq -- "queue · cache" --> RD
    Sidekiq -- "reindex docs" --> Meili
    Sidekiq -- "historical backfill" --> ES
    Sidekiq -. "internal JWT<br/>(internal only)" .-> Gateway

    RedisSub -- "PSUBSCRIBE" --> RD
    RedisSub --> InhouseQ
    RedisSub --> PhoenixEndpoint

    Gateway -- "rate limited" --> RiotAPI
    Router -- "pro matches" --> PandaScore
    Router -- "pro matches" --> Grid.gg
    Router -. "HTTP POST /recommend<br/>(fallback: DraftSuggester)" .-> MlService
    MlService --- MlModels

    ScraperCron -- "indexes new games" --> ES
    ScraperCron -- "polls events" --> LoLEsports
    Enrichment -- "enriches KDA/items" --> ES
    Enrichment -- "items/runes/KDA" --> Leaguepedia
    Backfill -- "historical backfill" --> ES
    Backfill -- "historical data" --> Leaguepedia
    ScraperApi -- "reads / status" --> ES

    %% === Estilos ===
    style FrontendApp fill:#1e88e5
    style PlayerPortal fill:#5c6bc0
    style Traefik fill:#1565c0
    style CoolifyNode fill:#0d47a1, stroke:#ffffff, stroke-width:3px
    style Cable fill:#b1003e
    style Sidekiq fill:#b1003e
    style PhoenixEndpoint fill:#4B275F
    style RedisSub fill:#4B275F
    style InhouseQ fill:#4B275F
    style Gateway fill:#00ADD8
    style PG fill:#336791
    style RD fill:#d82c20
    style Meili fill:#ff5722
    style ES fill:#005571
    style RiotAPI fill:#eb0029
    style PandaScore fill:#B069DB
    style Grid.gg fill:#000000
    style LoLEsports fill:#c89b3c
    style Leaguepedia fill:#8a6914
    style MlService fill:#1a6b3a
    style MlModels fill:#0f3d22
    style ScraperApi fill:#3d6b1a
    style ScraperCron fill:#2d5010
    style Enrichment fill:#2d5010
    style Backfill fill:#2d5010

```

> - **[View in Mermaid Live Editor](https://mermaidviewer.com/diagrams/_3ywx5nr73X6VrQF9XEn7)** 

### Scheduled Jobs (Sidekiq Scheduler)

```
╔══════════════════════════════╦═══════════════╦═══════════════════════════════════════════╗
║  Job                         ║  Schedule     ║  Description                              ║
╠══════════════════════════════╬═══════════════╬═══════════════════════════════════════════╣
║  CleanupExpiredTokensJob     ║  0 2 * * *    ║  Purge expired JWT blacklist + pwd tokens ║
║  RefreshMetadataViewsJob     ║  0 */2 * * *  ║  Refresh DB metadata materialized views   ║
║  HistoricalBackfillJob       ║  0 4 * * *    ║  CBLOL: Leaguepedia → ES → DB             ║
║  HistoricalBackfillJob       ║  30 4 * * *   ║  CBLOL Academy: Leaguepedia → ES → DB     ║
║  HistoricalBackfillJob       ║  0 5 * * *    ║  Circuito Desafiante: Leaguepedia → ES    ║
║  ScrimResultReminderJob      ║  0 10 * * *   ║  Send deadline reminders, expire reports  ║
║  RebuildChampionMatrixJob    ║  0 3 * * *    ║  Rebuild AI champion matrices/vectors     ║
║  StatusSnapshotJob           ║  */15 * * * * ║  Record component health snapshots        ║
╚══════════════════════════════╩═══════════════╩═══════════════════════════════════════════╝
```

> Backfill jobs are resumable — re-running skips already-completed tournaments. First run imports full history (~8-12h); subsequent runs only process new/failed tournaments (minutes).

**Production Stack (Coolify):**
- **Reverse Proxy**: Traefik with automatic TLS (Let's Encrypt)
- **Application**: Rails 7.2 API (Puma) + Action Cable + Sidekiq
- **Event Bus**: prostaff-events — Elixir/Phoenix 1.7 (domain events via Phoenix Channels)
- **Riot Gateway**: prostaff-riot-gateway — Go 1.23 (token bucket, L1/L2 cache, circuit breaker)
- **Database**: PostgreSQL 14+ (Supabase self-hosted)
- **Cache/Queue**: Redis 7
- **Search**: Meilisearch (self-hosted)
- **Data Lake**: Elasticsearch 8 (self-hosted, 97K+ pro games)

**Data Flow:**
1. Clients connect via HTTPS/WSS through Traefik
2. REST requests → Rails Router → PostgreSQL / Redis / Meilisearch / Elasticsearch
3. Team chat WebSocket → Action Cable → Redis pub/sub
4. Domain event WebSocket → prostaff-events (Phoenix Channels) ← Redis `PSUBSCRIBE prostaff:events:*` ← Rails
5. Riot API calls → prostaff-riot-gateway (rate limiter + cache) → Riot Games API
6. Background jobs → Sidekiq → PostgreSQL / Redis / Meilisearch / Elasticsearch / Gateway

---

### Environment Variables
<details>
<summary><kbd>▶ Environments (click to expand)</kbd></summary>


```bash
# Core
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://host:6379/0
SECRET_KEY_BASE=your-rails-secret

# Authentication
JWT_SECRET_KEY=your-production-secret

# External APIs
RIOT_API_KEY=your-riot-api-key
RIOT_GATEWAY_URL=http://riot-gateway:4444      # prostaff-riot-gateway internal URL
INTERNAL_JWT_SECRET=your-internal-jwt-secret  # shared with prostaff-riot-gateway (must match)
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

# Circuit breaker (optional, defaults shown)
CIRCUIT_BREAKER_THRESHOLD=5         # consecutive failures before opening circuit

# Elasticsearch data lake
ELASTICSEARCH_URL=https://user:password@elastic.example.com   # ES 8.x with basic auth

# ML AI Service (prostaff-ml FastAPI container)
# Local dev: http://localhost:8001 | Coolify production: http://ai-service:8001
AI_SERVICE_URL=http://ai-service:8001

# Historical backfill (Sidekiq scheduled jobs — override per-job via sidekiq.yml kwargs)
BACKFILL_LEAGUE=CBLOL               # default league for manual runs
BACKFILL_OUR_TEAM=paiN Gaming       # team name used in sync step
BACKFILL_MIN_YEAR=2013              # earliest year to import
BACKFILL_SYNC_LIMIT=500             # max matches synced per job run
SIDEKIQ_CONCURRENCY=10              # Sidekiq thread count (keep DB_POOL equal)
DB_POOL=10                          # ActiveRecord pool size for Sidekiq container
```
</details>


### Docker

```bash
docker build -t prostaff-api .
docker run -p 3333:3000 prostaff-api
```

---

## 12 · CI/CD

### CI/CD Workflows

|           Workflow     |                    Trigger              |                         What it does                                          |
|------------------------|-----------------------------------------|-------------------------------------------------------------------------------|
| `security-scan.yml`    | Push / PR → master, develop             | Brakeman, Bundle Audit, Semgrep, TruffleHog, SSRF + auth + SQLi runtime tests |
| `codeql.yml`           | Push / PR → master + Saturdays 3am UTC  | CodeQL `security-extended` + Actions workflows; SARIF to GitHub Security tab  |
| `nightly-security.yml` | Nightly 1am UTC + manual dispatch       | Full audit: Brakeman + Bundle Audit + ZAP baseline + ZAP API scan             |
| `load-test.yml`        | Manual dispatch                         | k6 smoke/load/stress tests                                                    |
| `snyk-container.yml`   | Push / PR → master, develop + weekly    | Snyk container image vulnerability scan                                       |
| `deploy-production.yml`| Push tag `v*.*.*` + manual dispatch     | Build, test, deploy to Coolify + CORS smoke test post-deploy                  |
| `deploy-staging.yml`   | Push → develop + manual dispatch        | Same pipeline targeting staging                                               |
| `update-architecture-diagram.yml`  Push / PR + manual dispatch   | Auto-regenerates Mermaid diagram and commits                                  |

### CodeQL Analysis

CodeQL runs as a complementary SAST engine alongside Brakeman and Semgrep, covering different vulnerability classes:

- SQL injection patterns outside standard ActiveRecord usage
- Path traversal in file operations
- SSRF in custom HTTP clients
- Code injection via `eval` / `send` with unsanitized input
- ReDoS (regex denial of service)

Results are published to the **GitHub Security tab** in SARIF format.

Config: `.github/codeql/codeql-config.yml` — analysis scoped to `app/`, `lib/`, `config/` (excludes vendor, tests, scripts).

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

See `.github/workflows/` for full workflow sources.

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
║  GNU Affero General Public License v3.0 (AGPLv3)                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE).

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
