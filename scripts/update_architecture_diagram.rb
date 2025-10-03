#!/usr/bin/env ruby
# frozen_string_literal: true

# This script analyzes the Rails application structure and updates the architecture diagram
# in README.md with current modules, controllers, models, and services

require 'pathname'
require 'set'

class ArchitectureDiagramGenerator
  RAILS_ROOT = Pathname.new(__dir__).join('..')
  README_PATH = RAILS_ROOT.join('README.md')

  def initialize
    @modules = discover_modules
    @models = discover_models
    @controllers = discover_controllers
    @services = discover_services
  end

  def run
    puts "Analyzing project structure..."
    diagram = generate_mermaid_diagram
    update_readme(diagram)
    puts "✅ Architecture diagram updated successfully!"
  end

  private

  def discover_modules
    modules_path = RAILS_ROOT.join('app', 'modules')
    return [] unless modules_path.exist?

    Dir.glob(modules_path.join('*')).select(&File.method(:directory?)).map do |dir|
      File.basename(dir)
    end.sort
  end

  def discover_models
    models_path = RAILS_ROOT.join('app', 'models')
    return [] unless models_path.exist?

    Dir.glob(models_path.join('*.rb')).map do |file|
      File.basename(file, '.rb')
    end.reject { |m| m == 'application_record' }.sort
  end

  def discover_controllers
    controllers = {}
    
    # Discover module controllers
    @modules.each do |mod|
      controllers_path = RAILS_ROOT.join('app', 'modules', mod, 'controllers')
      next unless controllers_path.exist?

      controllers[mod] = Dir.glob(controllers_path.join('*_controller.rb')).map do |file|
        File.basename(file, '_controller.rb')
      end
    end

    # Discover main API controllers
    api_controllers_path = RAILS_ROOT.join('app', 'controllers', 'api', 'v1')
    if api_controllers_path.exist?
      controllers['api_v1'] = Dir.glob(api_controllers_path.join('*_controller.rb')).map do |file|
        File.basename(file, '_controller.rb')
      end.reject { |c| c == 'base' }
    end

    controllers
  end

  def discover_services
    services = {}
    
    @modules.each do |mod|
      services_path = RAILS_ROOT.join('app', 'modules', mod, 'services')
      next unless services_path.exist?

      services[mod] = Dir.glob(services_path.join('*_service.rb')).map do |file|
        File.basename(file, '_service.rb')
      end
    end

    services
  end

  def generate_mermaid_diagram
    <<~MERMAID
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
      #{generate_module_sections}
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
          
      #{generate_router_connections}
      #{generate_data_connections}
      #{generate_external_connections}
          
          style Client fill:#e1f5ff
          style PostgreSQL fill:#336791
          style Redis fill:#d82c20
          style RiotAPI fill:#eb0029
          style Sidekiq fill:#b1003e
      ```
    MERMAID
  end

  def generate_module_sections
    sections = []

    # Authentication module
    sections << generate_auth_module if @modules.include?('authentication')

    # Other discovered modules
    (@modules - ['authentication']).each do |mod|
      sections << generate_generic_module(mod)
    end

    # Core modules based on routes and models
    sections << generate_dashboard_module if has_dashboard_routes?
    sections << generate_players_module if @models.include?('player')
    sections << generate_scouting_module if @models.include?('scouting_target')
    sections << generate_analytics_module if has_analytics_routes?
    sections << generate_matches_module if @models.include?('match')
    sections << generate_schedules_module if @models.include?('schedule')
    sections << generate_vod_module if @models.include?('vod_review')
    sections << generate_goals_module if @models.include?('team_goal')
    sections << generate_riot_module if has_riot_integration?

    sections.compact.join("\n")
  end

  def generate_auth_module
    <<~MODULE.chomp
            subgraph "Authentication Module"
                AuthController[Auth Controller]
                JWTService[JWT Service]
                UserModel[User Model]
            end
    MODULE
  end

  def generate_generic_module(name)
    <<~MODULE.chomp
            subgraph "#{name.capitalize} Module"
                #{name.capitalize}Controller[#{name.capitalize} Controller]
            end
    MODULE
  end

  def generate_dashboard_module
    <<~MODULE.chomp
            subgraph "Dashboard Module"
                DashboardController[Dashboard Controller]
                DashStats[Statistics Service]
            end
    MODULE
  end

  def generate_players_module
    <<~MODULE.chomp
            subgraph "Players Module"
                PlayersController[Players Controller]
                PlayerModel[Player Model]
                ChampionPool[Champion Pool Model]
            end
    MODULE
  end

  def generate_scouting_module
    <<~MODULE.chomp
            subgraph "Scouting Module"
                ScoutingController[Scouting Controller]
                ScoutingTarget[Scouting Target Model]
                Watchlist[Watchlist Service]
            end
    MODULE
  end

  def generate_analytics_module
    <<~MODULE.chomp
            subgraph "Analytics Module"
                AnalyticsController[Analytics Controller]
                PerformanceService[Performance Service]
                KDAService[KDA Trend Service]
            end
    MODULE
  end

  def generate_matches_module
    <<~MODULE.chomp
            subgraph "Matches Module"
                MatchesController[Matches Controller]
                MatchModel[Match Model]
                PlayerMatchStats[Player Match Stats Model]
            end
    MODULE
  end

  def generate_schedules_module
    <<~MODULE.chomp
            subgraph "Schedules Module"
                SchedulesController[Schedules Controller]
                ScheduleModel[Schedule Model]
            end
    MODULE
  end

  def generate_vod_module
    <<~MODULE.chomp
            subgraph "VOD Reviews Module"
                VODController[VOD Reviews Controller]
                VODModel[VOD Review Model]
                TimestampModel[Timestamp Model]
            end
    MODULE
  end

  def generate_goals_module
    <<~MODULE.chomp
            subgraph "Team Goals Module"
                GoalsController[Team Goals Controller]
                GoalModel[Team Goal Model]
            end
    MODULE
  end

  def generate_riot_module
    <<~MODULE.chomp
            subgraph "Riot Integration Module"
                RiotService[Riot API Service]
                RiotSync[Sync Service]
            end
    MODULE
  end

  def generate_router_connections
    connections = []
    connections << "    Router --> AuthController" if @modules.include?('authentication')
    connections << "    Router --> DashboardController" if has_dashboard_routes?
    connections << "    Router --> PlayersController" if @models.include?('player')
    connections << "    Router --> ScoutingController" if @models.include?('scouting_target')
    connections << "    Router --> AnalyticsController" if has_analytics_routes?
    connections << "    Router --> MatchesController" if @models.include?('match')
    connections << "    Router --> SchedulesController" if @models.include?('schedule')
    connections << "    Router --> VODController" if @models.include?('vod_review')
    connections << "    Router --> GoalsController" if @models.include?('team_goal')
    connections.join("\n")
  end

  def generate_data_connections
    connections = []
    
    # Auth connections
    if @modules.include?('authentication')
      connections << "    AuthController --> JWTService"
      connections << "    AuthController --> UserModel"
    end
    
    # Players connections
    if @models.include?('player')
      connections << "    PlayersController --> PlayerModel"
      connections << "    PlayerModel --> ChampionPool" if @models.include?('champion_pool')
    end
    
    # Scouting connections
    if @models.include?('scouting_target')
      connections << "    ScoutingController --> ScoutingTarget"
      connections << "    ScoutingController --> Watchlist"
    end
    
    # Matches connections
    if @models.include?('match')
      connections << "    MatchesController --> MatchModel"
      connections << "    MatchModel --> PlayerMatchStats" if @models.include?('player_match_stat')
    end
    
    # Other model connections
    connections << "    SchedulesController --> ScheduleModel" if @models.include?('schedule')
    
    if @models.include?('vod_review')
      connections << "    VODController --> VODModel"
      connections << "    VODModel --> TimestampModel" if @models.include?('vod_timestamp')
    end
    
    connections << "    GoalsController --> GoalModel" if @models.include?('team_goal')
    
    # Analytics connections
    if has_analytics_routes?
      connections << "    AnalyticsController --> PerformanceService"
      connections << "    AnalyticsController --> KDAService"
    end
    
    # Database connections
    @models.each do |model|
      model_name = model.split('_').map(&:capitalize).join
      connections << "    #{model_name}Model[#{model_name} Model] --> PostgreSQL"
    end
    
    # Redis connections
    connections << "    JWTService --> Redis" if @modules.include?('authentication')
    connections << "    DashStats --> Redis" if has_dashboard_routes?
    connections << "    PerformanceService --> Redis" if has_analytics_routes?
    
    connections.join("\n")
  end

  def generate_external_connections
    return "" unless has_riot_integration?

    <<~CONNECTIONS.chomp
        PlayersController --> RiotService
        MatchesController --> RiotService
        ScoutingController --> RiotService
        RiotService --> RiotAPI
        
        RiotService --> Sidekiq
        Sidekiq --> JobQueue
        JobQueue --> Redis
    CONNECTIONS
  end

  def has_dashboard_routes?
    routes_content = File.read(RAILS_ROOT.join('config', 'routes.rb'))
    routes_content.include?('dashboard')
  end

  def has_analytics_routes?
    routes_content = File.read(RAILS_ROOT.join('config', 'routes.rb'))
    routes_content.include?('analytics')
  end

  def has_riot_integration?
    gemfile = File.read(RAILS_ROOT.join('Gemfile'))
    gemfile.include?('faraday') || @services.values.any? { |s| s.include?('riot') }
  end

  def update_readme(diagram)
    content = File.read(README_PATH)
    
    # Find the architecture section
    arch_start = content.index('## Architecture')
    return unless arch_start

    # Find the end of architecture section (next ## heading or end of file)
    arch_end = content.index(/^## /, arch_start + 1) || content.length

    # Extract before and after sections
    before_arch = content[0...arch_start]
    after_arch = content[arch_end..-1]

    # Build new architecture section
    new_arch_section = <<~ARCH
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

      #{diagram}

      **Key Architecture Principles:**

      1. **Modular Monolith**: Each module is self-contained with its own controllers, models, and services
      2. **API-Only**: Rails configured in API mode for JSON responses
      3. **JWT Authentication**: Stateless authentication using JWT tokens
      4. **Background Processing**: Long-running tasks handled by Sidekiq
      5. **Caching**: Redis used for session management and performance optimization
      6. **External Integration**: Riot Games API integration for real-time data
      7. **Rate Limiting**: Rack::Attack for API rate limiting
      8. **CORS**: Configured for cross-origin requests from frontend

    ARCH

    # Write back to file
    File.write(README_PATH, before_arch + new_arch_section + after_arch)
  end
end

# Run the generator
ArchitectureDiagramGenerator.new.run
