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
        post 'auth/register', to: 'authentication/auth#register'
        post 'auth/login', to: 'authentication/auth#login'
        post 'auth/refresh', to: 'authentication/auth#refresh'
        post 'auth/logout', to: 'authentication/auth#logout'
        post 'auth/forgot-password', to: 'authentication/auth#forgot_password'
        post 'auth/reset-password', to: 'authentication/auth#reset_password'
        get 'auth/me', to: 'authentication/auth#me'
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
        end
        member do
          get :stats
          get :matches
        end
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