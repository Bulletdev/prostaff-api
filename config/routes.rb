Rails.application.routes.draw do
  # Mount Rswag API documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
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
        resources :watchlist, only: [:index, :create, :destroy]
      end

      # Analytics
      namespace :analytics do
        get 'performance', to: 'performance#index'
        get 'champions/:player_id', to: 'champions#show'
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
        resources :timestamps, controller: 'vod_timestamps', only: [:index, :create]
      end
      resources :vod_timestamps, path: 'vod-timestamps', only: [:update, :destroy]

      # Team Goals
      resources :team_goals, path: 'team-goals'
    end
  end

  # Mount Sidekiq web UI in development
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end