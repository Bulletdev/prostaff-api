# frozen_string_literal: true

Rails.application.routes.draw do
  # Handle CORS preflight requests (OPTIONS) for all routes
  match '*path', to: proc { [204, {}, ['']] }, via: :options

  # Action Cable WebSocket endpoint
  # Frontend connects via: wss://api/cable?token=<JWT>
  mount ActionCable.server => '/cable'

  # Mount Rswag API documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Health check endpoints
  #
  # /up              — backward-compatible alias (no dependency checks)
  # /health          — static 200 (no dependency checks, used by Traefik)
  # /health/live     — liveness probe: is Puma alive? Never checks dependencies.
  # /health/ready    — readiness probe: checks PostgreSQL + Redis + Meilisearch.
  # /health/detailed — legacy alias for /health/ready (backwards compat)
  #
  # See FAILURE_MODE_ANALYSIS.md: never add DB/Redis checks to /health/live.
  get 'up' => proc { [200, { 'Content-Type' => 'text/plain' }, ['ok']] }, as: :rails_health_check
  get 'health' => proc { [200, { 'Content-Type' => 'application/json' }, ['{"status":"ok","service":"ProStaff API"}']] }
  get 'health/live'     => 'health#live'
  get 'health/ready'    => 'health#ready'
  get 'health/detailed' => 'health#show'

  # Public status page API (used by status.prostaff.gg)
  get 'status' => 'status#index'

  # SEO - Sitemap
  get 'sitemap.xml', to: 'sitemap#index', defaults: { format: 'xml' }

  # API routes
  namespace :api do
    namespace :v1 do
      # Global full-text search (Meilisearch)
      get 'search', to: '/search/controllers/search#index'

      # Constants (public) -- stays in api/v1
      get 'constants', to: 'constants#index'

      # Image Proxy (public) -- stays in api/v1
      get 'images/proxy', to: 'images#proxy'

      # Auth
      scope :auth do
        post 'register', to: '/authentication/controllers/auth#register'
        post 'login', to: '/authentication/controllers/auth#login'
        post 'player-login',    to: '/authentication/controllers/auth#player_login'
        post 'player-register', to: '/authentication/controllers/auth#player_register'
        post 'refresh', to: '/authentication/controllers/auth#refresh'
        post 'logout', to: '/authentication/controllers/auth#logout'
        post 'forgot-password', to: '/authentication/controllers/auth#forgot_password'
        post 'reset-password', to: '/authentication/controllers/auth#reset_password'
        get 'me', to: '/authentication/controllers/auth#me'
      end

      # Organization settings (for current user's org)
      scope 'organizations/:id', as: 'organization' do
        patch '', to: 'organizations#update', as: 'update'
        post 'logo', to: 'organizations#upload_logo', as: 'logo'
        patch 'lines', to: 'organizations#update_lines', as: 'update_lines'
      end

      # Profile -- stays in api/v1
      scope :profile do
        get '', to: 'profile#show'
        patch '', to: 'profile#update'
        patch 'password', to: 'profile#update_password'
        patch 'notifications', to: 'profile#update_notifications'
      end

      # Feedback
      resources :feedbacks, only: %i[index create] do
        member do
          post :vote
        end
      end

      # Notifications
      resources :notifications, only: %i[index show destroy],
                                controller: '/notifications/controllers/notifications' do
        member do
          patch :mark_as_read
        end
        collection do
          patch :mark_all_as_read
          get :unread_count
        end
      end

      # Dashboard
      resources :dashboard, only: [:index],
                            controller: '/dashboard/controllers/dashboard' do
        collection do
          get :stats
          get :activities
          get :schedule
        end
      end

      # Players
      resources :players, controller: '/players/controllers/players' do
        collection do
          get :stats
          post :import
          post :bulk_sync
          get :search_riot_id
          get 'by_discord/:discord_user_id', action: :by_discord, as: :by_discord
        end
        member do
          get :stats
          get :matches
          post :sync_from_riot
          post :link_discord
          get 'stats/export', to: '/players/controllers/stats_export#show', as: :stats_export
        end
      end

      # Roster Management
      post 'rosters/remove/:player_id', to: '/players/controllers/rosters#remove_from_roster'
      post 'rosters/hire/:scouting_target_id', to: '/players/controllers/rosters#hire_from_scouting'
      get 'rosters/free-agents', to: '/players/controllers/rosters#free_agents'
      get 'rosters/statistics', to: '/players/controllers/rosters#statistics'

      # Admin
      scope '/admin', as: 'admin' do
        resources :players, only: [:index],
                            controller: '/admin/controllers/players' do
          member do
            post :soft_delete
            post :restore
            post :enable_access
            post :disable_access
            post :transfer
            post :change_status
          end
        end

        # Organizations overview
        resources :organizations, only: [:index],
                                  controller: '/admin/controllers/organizations'

        # Audit Logs
        resources :audit_logs, only: [:index], path: 'audit-logs',
                               controller: '/admin/controllers/audit_logs'

        # Status Incidents
        resources :status_incidents, path: 'status/incidents',
                                     controller: '/admin/controllers/status_incidents' do
          member do
            post :updates, action: :add_update
          end
        end
      end

      # Monitoring (admin-only observability) -- stays in api/v1
      get 'monitoring/sidekiq',     to: 'monitoring#sidekiq'
      get 'monitoring/cache_stats', to: 'monitoring#cache_stats'

      # Support System
      scope '/support', as: 'support' do
        # User tickets
        resources :tickets, controller: '/support/controllers/tickets' do
          member do
            post :close
            post :reopen
            post 'messages', action: :add_message
          end
        end

        # FAQ
        resources :faq, only: %i[index show], param: :slug,
                        controller: '/support/controllers/faqs' do
          member do
            post :helpful, action: :mark_helpful
            post 'not-helpful', action: :mark_not_helpful
          end
        end

        # File uploads for attachments
        post 'uploads', to: '/support/controllers/uploads#create'

        # Staff operations
        scope '/staff', as: 'staff' do
          get 'dashboard', to: '/support/controllers/staff#dashboard'
          get 'analytics', to: '/support/controllers/staff#analytics'

          resources :tickets, only: [] do
            member do
              post :assign, to: '/support/controllers/staff#assign'
              post :resolve, to: '/support/controllers/staff#resolve'
            end
          end
        end
      end

      # Riot Integration
      scope :riot_integration do
        get :sync_status, to: '/riot_integration/controllers/riot_integration#sync_status'
      end

      # Riot Data (Data Dragon)
      scope 'riot-data' do
        get 'champions', to: '/riot_integration/controllers/riot_data#champions'
        get 'champions/:champion_key', to: '/riot_integration/controllers/riot_data#champion_details'
        get 'all-champions', to: '/riot_integration/controllers/riot_data#all_champions'
        get 'items', to: '/riot_integration/controllers/riot_data#items'
        get 'summoner-spells', to: '/riot_integration/controllers/riot_data#summoner_spells'
        get 'version', to: '/riot_integration/controllers/riot_data#version'
        post 'clear-cache', to: '/riot_integration/controllers/riot_data#clear_cache'
        post 'update-cache', to: '/riot_integration/controllers/riot_data#update_cache'
      end

      # Scouting
      scope '/scouting', as: 'scouting' do
        resources :players, controller: '/scouting/controllers/players' do
          member do
            post :sync
            post :import_to_roster
          end
        end
        get 'regions', to: '/scouting/controllers/regions#index'
        resources :watchlist, only: %i[index create destroy],
                              controller: '/scouting/controllers/watchlist'
      end

      # Analytics
      scope '/analytics', as: 'analytics' do
        get 'performance', to: '/analytics/controllers/performance#index'
        get 'champions/:player_id', to: '/analytics/controllers/champions#show'
        get 'champions/:player_id/details', to: '/analytics/controllers/champions#details'
        get 'kda-trend/:player_id', to: '/analytics/controllers/kda_trend#show'
        get 'laning/:player_id', to: '/analytics/controllers/laning#show'
        get 'teamfights/:player_id', to: '/analytics/controllers/teamfights#show'
        get 'vision/:player_id', to: '/analytics/controllers/vision#show'
        get 'team-comparison', to: '/analytics/controllers/team_comparison#index'

        # Objective analytics (dragon, baron, tower, inhibitor control)
        get 'objectives', to: '/analytics/controllers/objectives#index'

        # Ping Profile analytics
        get 'players/:player_id/ping-profile', to: '/analytics/controllers/ping_profile#show',
                                               as: 'ping_profile'

        # Competitive analytics (draft performance, tournament stats, opponent analysis)
        get 'competitive/draft-performance', to: '/analytics/controllers/competitive#draft_performance'
        get 'competitive/tournament-stats',  to: '/analytics/controllers/competitive#tournament_stats'
        get 'competitive/opponents',         to: '/analytics/controllers/competitive#opponents'
        get 'competitive/player-stats',      to: '/analytics/controllers/competitive_player#player_stats'
      end

      # Matches
      resources :matches, controller: '/matches/controllers/matches' do
        collection do
          post :import
        end
        member do
          get :stats
          get :export, to: '/matches/controllers/export#show'
        end
      end

      # Schedules
      resources :schedules, controller: '/schedules/controllers/schedules'

      # VOD Reviews
      resources :vod_reviews, path: 'vod-reviews',
                              controller: '/vod_reviews/controllers/vod_reviews' do
        resources :timestamps, controller: '/vod_reviews/controllers/vod_timestamps',
                               only: %i[index create]
      end
      resources :vod_timestamps, path: 'vod-timestamps',
                                 controller: '/vod_reviews/controllers/vod_timestamps',
                                 only: %i[update destroy]

      # Team Goals
      resources :team_goals, path: 'team-goals',
                             controller: '/team_goals/controllers/team_goals'

      # Scrims Module (Tier 2+)
      scope '/scrims', as: 'scrims' do
        # Public lobby — no auth required (scrims.lol feed)
        get 'lobby', to: '/scrims/controllers/lobby#index'

        resources :scrims, controller: '/scrims/controllers/scrims' do
          member do
            post :add_game
          end
          collection do
            get :calendar
            get :analytics
          end
          resources :messages, only: %i[index destroy],
                               controller: '/scrims/controllers/scrim_messages',
                               as: :scrim_messages
          resource :result, only: %i[show create],
                            controller: '/scrims/controllers/scrim_result_reports',
                            as: :scrim_result
        end

        resources :opponent_teams, path: 'opponent-teams',
                                   controller: '/scrims/controllers/opponent_teams' do
          member do
            get :scrim_history, path: 'scrim-history'
          end
        end
      end

      # Inhouse Module — internal practice sessions between org's own players
      scope '/inhouse', as: 'inhouse' do
        get 'ladder',                    to: '/inhouses/controllers/inhouses#ladder'
        get 'ladder/:player_id/ratings', to: '/inhouses/controllers/inhouses#player_ratings', as: 'player_ratings'
        get 'sessions',                  to: '/inhouses/controllers/inhouses#sessions'

        # Role-based queue (server-side, used by web dashboard + Discord bot)
        scope '/queue', as: 'queue' do
          get  'status',        to: '/inhouses/controllers/inhouse_queues#status'
          post 'open',          to: '/inhouses/controllers/inhouse_queues#open'
          post 'join',          to: '/inhouses/controllers/inhouse_queues#join'
          post 'leave',         to: '/inhouses/controllers/inhouse_queues#leave'
          post 'start_checkin', to: '/inhouses/controllers/inhouse_queues#start_checkin'
          post 'checkin',       to: '/inhouses/controllers/inhouse_queues#checkin'
          post 'start_session', to: '/inhouses/controllers/inhouse_queues#start_session'
          post 'close',         to: '/inhouses/controllers/inhouse_queues#close'
        end

        resources :inhouses, controller: '/inhouses/controllers/inhouses', only: %i[index create] do
          collection do
            get :active
          end
          member do
            post :join
            post :balance_teams
            post :start_draft
            post :captain_pick
            post :start_game
            post :record_game
            patch :close
          end
        end
      end

      # Matchmaking Module — scrims.lol cross-org scheduling
      scope '/matchmaking', as: 'matchmaking' do
        get 'suggestions', to: '/matchmaking/controllers/scrim_requests#suggestions'

        resources :availability_windows, path: 'availability-windows',
                                         controller: '/matchmaking/controllers/availability_windows'

        resources :scrim_requests, path: 'scrim-requests',
                                   controller: '/matchmaking/controllers/scrim_requests',
                                   only: %i[index show create] do
          member do
            patch :accept
            patch :decline
            patch :cancel
          end
        end
      end

      # Competitive Module - PandaScore Integration
      # Controllers live in Competitive::Controllers:: (app/modules/competitive/controllers/).
      scope '/competitive', as: 'competitive' do
        # Pro Matches from PandaScore / ProStaff Scraper
        resources :pro_matches, path: 'pro-matches',
                                controller: '/competitive/controllers/pro_matches',
                                only: %i[index show] do
          collection do
            get :upcoming
            get :past
            post :refresh
            post :import
            post 'sync-from-scraper',      action: :sync_from_scraper
            post 'sync-from-leaguepedia',  action: :sync_from_leaguepedia
            get  'match-preview',           action: :match_preview
            get  'es-series',              action: :es_series
            get  'diagnose-missing',       action: :diagnose_missing
            post 'recover-missing',        action: :recover_missing
            post 'historical-backfill',        action: :historical_backfill
            get  'historical-backfill/status', action: :historical_backfill_status
          end
        end

        # Draft Comparison & Meta Analysis
        post 'draft-comparison', to: '/competitive/controllers/draft_comparison#compare',
                                 as: 'draft_comparison'
        get 'meta/:role',        to: '/competitive/controllers/draft_comparison#meta_by_role',
                                 as: 'meta'
        get 'composition-winrate', to: '/competitive/controllers/draft_comparison#composition_winrate',
                                   as: 'composition_winrate'
        get 'counters',          to: '/competitive/controllers/draft_comparison#suggest_counters',
                                 as: 'counters'
      end

      # Strategy Module - Draft & Tactical Planning
      scope '/strategy', as: 'strategy' do
        # Draft Plans
        resources :draft_plans, path: 'draft-plans',
                                controller: '/strategy/controllers/draft_plans' do
          member do
            post :analyze
            patch :activate
            patch :deactivate
          end
        end

        # Tactical Boards
        resources :tactical_boards, path: 'tactical-boards',
                                    controller: '/strategy/controllers/tactical_boards' do
          member do
            get :statistics
          end
        end

        # Assets endpoints
        get 'assets/champion/:champion_name', to: '/strategy/controllers/assets#champion_assets'
        get 'assets/map', to: '/strategy/controllers/assets#map_assets'
      end

      # Fantasy Module - Coming Soon Waitlist
      scope '/fantasy', as: 'fantasy' do
        post 'waitlist', to: '/core/controllers/waitlist#create'
        get 'waitlist/stats', to: '/core/controllers/waitlist#stats'
      end

      # Meta Intelligence Module
      # Item tier lists and build analytics derived from match history.
      scope '/meta', as: 'meta_intelligence' do
        get 'items',     to: '/meta_intelligence/controllers/items#index', as: 'meta_items'
        get 'items/:id', to: '/meta_intelligence/controllers/items#show',  as: 'meta_item'

        resources :builds,
                  controller: '/meta_intelligence/controllers/builds',
                  only: %i[index show create update destroy] do
          collection do
            post :aggregate
          end
        end

        get 'champions/:champion',
            to: '/meta_intelligence/controllers/champion_meta#show',
            as: 'meta_champion'
      end

      # Contact form (public, no auth)
      post 'contact', to: 'contact#create'

      # Team Messaging -- DM history + soft-delete
      resources :messages, only: %i[index destroy],
                           controller: '/messaging/controllers/messages'

      # Team members list (for chat widget)
      get 'team-members', to: '/core/controllers/team_members#index'

      # AI Intelligence Module — draft analysis and win probability
      # Requires Tier 1 (Professional) subscription.
      namespace :ai do
        post 'draft/analyze', to: '/ai_intelligence/controllers/draft#analyze'
      end

      # Tournaments Module — ArenaBR double elimination
      resources :tournaments, controller: '/tournaments/controllers/tournaments',
                              only: %i[index show create update] do
        member do
          post :generate_bracket
        end

        resources :teams, only: %i[index create destroy],
                          controller: '/tournaments/controllers/tournament_teams' do
          member do
            patch :approve
            patch :reject
          end
        end

        resources :matches, only: %i[index show],
                            controller: '/tournaments/controllers/tournament_matches' do
          member do
            post :checkin
          end

          resource :report, only: %i[show create],
                            controller: '/tournaments/controllers/match_reports' do
            post :admin_resolve, on: :member
          end
        end
      end
    end
  end

  # Internal service-to-service routes — authenticated via INTERNAL_JWT_SECRET only.
  # Used by prostaff-events for startup reconciliation of active InhouseQueues.
  namespace :internal do
    namespace :api do
      get 'inhouse_queues/active', to: '/inhouses/controllers/internal/inhouse_queues#active'
    end
  end

  require 'sidekiq/web'
  Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
    expected_user     = ENV.fetch('SIDEKIQ_WEB_USER', nil)
    expected_password = ENV.fetch('SIDEKIQ_WEB_PASSWORD', nil)

    next false if expected_user.blank? || expected_password.blank?

    user_match = ActiveSupport::SecurityUtils.secure_compare(user, expected_user)
    password_match = ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(password),
      ::Digest::SHA256.hexdigest(expected_password)
    )

    user_match && password_match
  end
  # Rails API mode strips session middleware — Sidekiq::Web needs it for CSRF
  Sidekiq::Web.use Rack::Session::Cookie,
                   secret: Rails.application.secret_key_base,
                   same_site: true,
                   max_age: 86_400
  mount Sidekiq::Web => '/sidekiq'
end
