# frozen_string_literal: true

Rails.application.routes.draw do
  # Handle CORS preflight requests (OPTIONS) for all routes
  match '*path', to: proc { [204, {}, ['']] }, via: :options

  # Mount Rswag API documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Health check endpoints (Railway external health check)
  # Simple health check without DB dependency (for Railway healthcheck)
  get 'up' => proc { [200, { 'Content-Type' => 'text/plain' }, ['ok']] }, as: :rails_health_check
  get 'health' => proc { [200, { 'Content-Type' => 'application/json' }, ['{"status":"ok","service":"ProStaff API"}']] }
  get 'health/detailed' => 'health#show'  # Detailed health with DB check

  # SEO - Sitemap
  get 'sitemap.xml', to: 'sitemap#index', defaults: { format: 'xml' }

  # API routes
  namespace :api do
    namespace :v1 do
      # Constants (public)
      get 'constants', to: 'constants#index'

      # Auth
      scope :auth do
        post 'register', to: 'auth#register'
        post 'login', to: 'auth#login'
        post 'refresh', to: 'auth#refresh'
        post 'logout', to: 'auth#logout'
        post 'forgot-password', to: 'auth#forgot_password'
        post 'reset-password', to: 'auth#reset_password'
        get 'me', to: 'auth#me'
      end

      # Notifications
      resources :notifications, only: %i[index show destroy] do
        member do
          patch :mark_as_read, to: 'notifications#mark_as_read'
        end
        collection do
          patch :mark_all_as_read, to: 'notifications#mark_all_as_read'
          get :unread_count, to: 'notifications#unread_count'
        end
      end

      # Dashboard
      resources :dashboard, only: [:index] do
        collection do
          get :stats
          get :activities
          get :schedule
        end
      end

      # Players
      resources :players do
        collection do
          get :stats
          post :import
          post :bulk_sync
          get :search_riot_id
        end
        member do
          get :stats
          get :matches
          post :sync_from_riot
        end
      end

      # Roster Management
      post 'rosters/remove/:player_id', to: 'rosters#remove_from_roster'
      post 'rosters/hire/:scouting_target_id', to: 'rosters#hire_from_scouting'
      get 'rosters/free-agents', to: 'rosters#free_agents'
      get 'rosters/statistics', to: 'rosters#statistics'

      # Admin - Player Management
      namespace :admin do
        resources :players, only: [:index] do
          member do
            post :soft_delete
            post :restore
            post :enable_access
            post :disable_access
            post :transfer
          end
        end

        # Audit Logs
        resources :audit_logs, only: [:index], path: 'audit-logs'
      end

      # Support System
      namespace :support do
        # User tickets
        resources :tickets do
          member do
            post :close
            post :reopen
            post 'messages', to: 'tickets#add_message'
          end
        end

        # FAQ
        resources :faq, only: [:index, :show], param: :slug, controller: 'faqs' do
          member do
            post :helpful, to: 'faqs#mark_helpful'
            post 'not-helpful', to: 'faqs#mark_not_helpful'
          end
        end

        # Staff operations
        namespace :staff do
          get 'dashboard', to: 'staff#dashboard'
          get 'analytics', to: 'staff#analytics'

          resources :tickets, only: [] do
            member do
              post :assign
              post :resolve
            end
          end
        end
      end

      # Riot Integration
      scope :riot_integration, controller: 'riot_integration' do
        get :sync_status
      end

      # Riot Data (Data Dragon)
      scope 'riot-data', controller: 'riot_data' do
        get 'champions', to: 'riot_data#champions'
        get 'champions/:champion_key', to: 'riot_data#champion_details'
        get 'all-champions', to: 'riot_data#all_champions'
        get 'items', to: 'riot_data#items'
        get 'summoner-spells', to: 'riot_data#summoner_spells'
        get 'version', to: 'riot_data#version'
        post 'clear-cache', to: 'riot_data#clear_cache'
        post 'update-cache', to: 'riot_data#update_cache'
      end

      # Scouting
      namespace :scouting do
        resources :players do
          member do
            post :sync
          end
        end
        get 'regions', to: 'regions#index'
        resources :watchlist, only: %i[index create destroy]
      end

      # Analytics
      namespace :analytics do
        get 'performance', to: 'performance#index'
        get 'champions/:player_id', to: 'champions#show'
        get 'champions/:player_id/details', to: 'champions#details'
        get 'kda-trend/:player_id', to: 'kda_trend#show'
        get 'laning/:player_id', to: 'laning#show'
        get 'teamfights/:player_id', to: 'teamfights#show'
        get 'vision/:player_id', to: 'vision#show'
        get 'team-comparison', to: 'team_comparison#index'
      end

      # Matches
      resources :matches do
        collection do
          post :import
        end
        member do
          get :stats
        end
      end

      # Schedules
      resources :schedules

      # VOD Reviews
      resources :vod_reviews, path: 'vod-reviews' do
        resources :timestamps, controller: 'vod_timestamps', only: %i[index create]
      end
      resources :vod_timestamps, path: 'vod-timestamps', only: %i[update destroy]

      # Team Goals
      resources :team_goals, path: 'team-goals'

      # Scrims Module (Tier 2+)
      namespace :scrims do
        resources :scrims do
          member do
            post :add_game
          end
          collection do
            get :calendar
            get :analytics
          end
        end

        resources :opponent_teams, path: 'opponent-teams' do
          member do
            get :scrim_history, path: 'scrim-history'
          end
        end
      end

      # Competitive Matches (Tier 1)
      resources :competitive_matches, path: 'competitive-matches', only: %i[index show]

      # Competitive Module - PandaScore Integration
      namespace :competitive do
        # Pro Matches from PandaScore
        resources :pro_matches, path: 'pro-matches', only: %i[index show] do
          collection do
            get :upcoming
            get :past
            post :refresh
            post :import
          end
        end

        # Draft Comparison & Meta Analysis
        post 'draft-comparison', to: 'draft_comparison#compare'
        get 'meta/:role', to: 'draft_comparison#meta_by_role'
        get 'composition-winrate', to: 'draft_comparison#composition_winrate'
        get 'counters', to: 'draft_comparison#suggest_counters'
      end

      # Strategy Module - Draft & Tactical Planning
      namespace :strategy do
        # Draft Plans
        resources :draft_plans, path: 'draft-plans' do
          member do
            post :analyze
            patch :activate
            patch :deactivate
          end
        end

        # Tactical Boards
        resources :tactical_boards, path: 'tactical-boards' do
          member do
            get :statistics
          end
        end

        # Assets endpoints
        get 'assets/champion/:champion_name', to: 'assets#champion_assets'
        get 'assets/map', to: 'assets#map_assets'
      end

      # Fantasy Module - Coming Soon Waitlist
      namespace :fantasy do
        post 'waitlist', to: 'waitlist#create'
        get 'waitlist/stats', to: 'waitlist#stats'
      end
    end
  end

  # Mount Sidekiq web UI in development
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
