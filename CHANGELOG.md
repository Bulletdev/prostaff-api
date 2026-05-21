# Changelog

All notable changes to ProStaff API will be documented in this file.

---

## [1.0.3] - 2026-03-23

### Added

#### Support System
- Full support ticket lifecycle: create, view, update, close, reopen
- Support ticket messages with types: `user`, `staff`, `system`, `chatbot`
- Staff dashboard with real-time stats (open, in_progress, waiting_user, urgent, unassigned, my tickets)
- Staff analytics: tickets created/resolved, avg response time, avg resolution time, resolution rate, trending issues by category
- Ticket assignment and resolution by staff members with audit logging
- Chatbot integration (OpenAI) on ticket creation with FAQ suggestions and LLM solution

#### File Attachments (Supabase S3)
- `POST /api/v1/support/uploads` — authenticated file upload endpoint
- Supabase S3-compatible storage via `aws-sdk-s3`
- Validation: allowed MIME types (image/*, PDF, TXT, CSV), max 10MB per file
- Pre-signed URL generation (1h expiry) on message serialization
- Attachments stored as JSONB on `support_ticket_messages`

#### Internal Messenger
- Real-time team chat via Action Cable (WebSockets)
- JWT authentication over WebSocket query param
- Organization-scoped message streams
- REST endpoint for message history

#### Mailer
- Contact form email delivery via SMTP
- Conditional mailer (no-op when SMTP not configured)

#### Feedback
- `POST /api/v1/feedbacks` — user feedback submission
- `POST /api/v1/feedbacks/:id/vote` — upvote feedback items

#### AI Intelligence Module
- Draft analysis and insights powered by OpenAI
- Aggressive timeout (<10s) to prevent blocking requests

### Changed

- Support ticket `category` validation now includes `getting_started`
- Support ticket `status` field uses `waiting_user` (renamed from `waiting_client`)
- `SupportTicketMessage#create_system_message` falls back to ticket owner when no staff assigned
- `tickets_controller` serializer now includes `attachments` with signed URLs on all messages
- `message_params` strong params updated to accept structured attachment objects (`%i[key filename content_type size]`)

### Fixed

- `SupportTicket#ticket_number` — removed unsafe navigation chain causing RuboCop `SafeNavigationChainLength` offense
- `StaffController#calculate_dashboard_stats` — corrected `waiting_client` to `waiting_user` key
- `UploadsController` — corrected `unless` modifier style per RuboCop `Style/IfUnlessModifier`
- Mail logger warning in production (conditional SMTP setup)

### Security

- Upload endpoint requires authentication (`authenticate_request!` via `BaseController`)
- File type whitelist enforced server-side (rejects `application/octet-stream` and other binary types)
- S3 credentials stored exclusively in environment variables, never in source code

---

## [1.0.2] - 2026-02-25

### Added
- Failure mode analysis documentation (FAILURE_MODE_ANALYSIS.md)
- Redis identified as SPOF for ActionCable, Sidekiq, Rack::Attack, and cache subsystems

### Changed
- Real-time messaging (Action Cable) with JWT auth and organization isolation
- Lograge structured JSON logging

### Fixed
- Data loss incident protections: guard in `rails_helper.rb` aborts tests if `DATABASE_URL` points to production
- `.env.test` created with local PostgreSQL exclusively for tests
- Daily backup script: `scripts/backup_database.sh` (cron 3AM, 30-day retention)

---

## [1.0.1] - 2025-10-25

### Added
- k6 load testing suite (smoke, load, stress scenarios)
- OWASP security test suite
- CI/CD workflows: security scan on every push, nightly full audit
- Redis caching on dashboard/stats (5min TTL)
- 8 database indexes on hot query paths

### Changed
- Code quality overhaul: Codacy issues reduced from 1,569 to 219 (86% reduction)
- Grade improved from C to A-
- YARD documentation added to 22 files

### Fixed
- N+1 queries via `.includes()` on player and match endpoints
- RuboCop offenses across analytics, scouting, and auth modules

---

## [1.0.0] - 2025-09-01

### Added
- Initial release
- JWT authentication with refresh tokens and token blacklist
- Multi-tenant organization structure
- Player management with Riot API sync (Sidekiq jobs)
- Match history via Riot API + PandaScore
- VOD reviews with timestamps
- Team goals tracking
- Player scouting and watchlist
- Analytics and performance metrics
- Full-text search via Meilisearch
- Pundit authorization
- Rack::Attack rate limiting
- Swagger/Rswag API documentation
