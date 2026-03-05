#!/usr/bin/env ruby
# frozen_string_literal: true

# This script analyzes the Rails application structure and updates the architecture diagram
# in README.md with current modules, controllers, models, and services

require 'pathname'

# Generates and updates the Mermaid architecture diagram in README.md
# by introspecting Rails modules, models, controllers, and services.
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
    puts 'Analyzing project structure...'
    diagram = generate_mermaid_diagram
    update_readme(diagram)
    export_mermaid_file(diagram)
    puts ' Architecture diagram updated successfully!'
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
    models = []

    # Discover models in app/models
    models_path = RAILS_ROOT.join('app', 'models')
    if models_path.exist?
      models += Dir.glob(models_path.join('*.rb')).map do |file|
        File.basename(file, '.rb')
      end
    end

    # Discover models in app/modules/*/models
    modules_path = RAILS_ROOT.join('app', 'modules')
    if modules_path.exist?
      models += Dir.glob(modules_path.join('*', 'models', '*.rb')).map do |file|
        File.basename(file, '.rb')
      end
    end

    models.reject { |m| m == 'application_record' }.uniq.sort
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
              PandaScoreAPI[PandaScore API]
          end

          Client -->|HTTP/JSON| CORS
          CORS --> RateLimit
          RateLimit --> Auth
          Auth --> Router
      #{'    '}
      #{generate_router_connections}
      #{generate_data_connections}
      #{generate_external_connections}
      #{'    '}
          style Client fill:#e1f5ff
          style PostgreSQL fill:#336791
          style Redis fill:#d82c20
          style RiotAPI fill:#eb0029
          style PandaScoreAPI fill:#ff6b35
          style Sidekiq fill:#b1003e
      ```
    MERMAID
  end

  def generate_module_sections
    (core_module_sections + gameplay_module_sections + extended_module_sections)
      .compact
      .join("\n\n")
  end

  def core_module_sections
    [
      (@modules.include?('authentication') ? generate_auth_module : nil),
      (has_dashboard_routes? ? generate_dashboard_module : nil),
      (@models.include?('player') ? generate_players_module : nil),
      (@models.include?('scouting_target') ? generate_scouting_module : nil)
    ]
  end

  def gameplay_module_sections
    [
      (has_analytics_routes? ? generate_analytics_module : nil),
      (@models.include?('match') ? generate_matches_module : nil),
      (@models.include?('schedule') ? generate_schedules_module : nil),
      (@models.include?('vod_review') ? generate_vod_module : nil),
      (@models.include?('team_goal') ? generate_goals_module : nil),
      (has_riot_integration? ? generate_riot_module : nil)
    ]
  end

  def extended_module_sections
    strategy_module = (generate_strategy_module if @models.include?('draft_plan') || @models.include?('tactical_board'))
    [
      (@modules.include?('competitive') ? generate_competitive_module : nil),
      (@modules.include?('scrims') ? generate_scrims_module : nil),
      strategy_module,
      (@models.include?('support_ticket') ? generate_support_module : nil)
    ]
  end

  # Helper to indent module content
  def indent_module(content)
    content.split("\n").map { |line| "        #{line}" }.join("\n")
  end

  def generate_auth_module
    indent_module(<<~MODULE.chomp)
      subgraph "Authentication Module"
          AuthController[Auth Controller]
          JWTService[JWT Service]
          UserModel[User Model]
      end
    MODULE
  end

  def generate_generic_module(name)
    indent_module(<<~MODULE.chomp)
      subgraph "#{name.capitalize} Module"
          #{name.capitalize}Controller[#{name.capitalize} Controller]
      end
    MODULE
  end

  def generate_dashboard_module
    indent_module(<<~MODULE.chomp)
      subgraph "Dashboard Module"
          DashboardController[Dashboard Controller]
          DashStats[Statistics Service]
      end
    MODULE
  end

  def generate_players_module
    indent_module(<<~MODULE.chomp)
      subgraph "Players Module"
          PlayersController[Players Controller]
          PlayerModel[Player Model]
          ChampionPoolModel[Champion Pool Model]
      end
    MODULE
  end

  def generate_scouting_module
    indent_module(<<~MODULE.chomp)
      subgraph "Scouting Module"
          ScoutingController[Scouting Controller]
          ScoutingTargetModel[Scouting Target Model]
          Watchlist[Watchlist Service]
      end
    MODULE
  end

  def generate_analytics_module
    indent_module(<<~MODULE.chomp)
      subgraph "Analytics Module"
          AnalyticsController[Analytics Controller]
          PerformanceService[Performance Service]
          KDAService[KDA Trend Service]
      end
    MODULE
  end

  def generate_matches_module
    indent_module(<<~MODULE.chomp)
      subgraph "Matches Module"
          MatchesController[Matches Controller]
          MatchModel[Match Model]
          PlayerMatchStatModel[Player Match Stat Model]
      end
    MODULE
  end

  def generate_schedules_module
    indent_module(<<~MODULE.chomp)
      subgraph "Schedules Module"
          SchedulesController[Schedules Controller]
          ScheduleModel[Schedule Model]
      end
    MODULE
  end

  def generate_vod_module
    indent_module(<<~MODULE.chomp)
      subgraph "VOD Reviews Module"
          VODController[VOD Reviews Controller]
          VodReviewModel[VOD Review Model]
          VodTimestampModel[VOD Timestamp Model]
      end
    MODULE
  end

  def generate_goals_module
    indent_module(<<~MODULE.chomp)
      subgraph "Team Goals Module"
          GoalsController[Team Goals Controller]
          TeamGoalModel[Team Goal Model]
      end
    MODULE
  end

  def generate_riot_module
    indent_module(<<~MODULE.chomp)
      subgraph "Riot Integration Module"
          RiotService[Riot API Service]
          RiotSync[Sync Service]
      end
    MODULE
  end

  def generate_competitive_module
    indent_module(<<~MODULE.chomp)
      subgraph "Competitive Module"
          CompetitiveController[Competitive Controller]
          ProMatchesController[Pro Matches Controller]
          PandaScoreService[PandaScore Service]
          DraftAnalyzer[Draft Analyzer]
      end
    MODULE
  end

  def generate_scrims_module
    indent_module(<<~MODULE.chomp)
      subgraph "Scrims Module"
          ScrimsController[Scrims Controller]
          OpponentTeamsController[Opponent Teams Controller]
          ScrimAnalytics[Scrim Analytics Service]
      end
    MODULE
  end

  def generate_strategy_module
    indent_module(<<~MODULE.chomp)
      subgraph "Strategy Module"
          DraftPlansController[Draft Plans Controller]
          TacticalBoardsController[Tactical Boards Controller]
          DraftAnalysisService[Draft Analysis Service]
      end
    MODULE
  end

  def generate_support_module
    indent_module(<<~MODULE.chomp)
      subgraph "Support Module"
          SupportTicketsController[Support Tickets Controller]
          SupportFaqsController[Support FAQs Controller]
          SupportStaffController[Support Staff Controller]
          SupportTicketModel[Support Ticket Model]
          SupportFaqModel[Support FAQ Model]
      end
    MODULE
  end

  def generate_router_connections
    (basic_router_connections + module_router_connections).join("\n")
  end

  def basic_router_connections
    connections = []
    connections << '    Router --> AuthController' if @modules.include?('authentication')
    connections << '    Router --> DashboardController' if has_dashboard_routes?
    connections << '    Router --> PlayersController' if @models.include?('player')
    connections << '    Router --> ScoutingController' if @models.include?('scouting_target')
    connections << '    Router --> AnalyticsController' if has_analytics_routes?
    connections << '    Router --> MatchesController' if @models.include?('match')
    connections << '    Router --> SchedulesController' if @models.include?('schedule')
    connections << '    Router --> VODController' if @models.include?('vod_review')
    connections << '    Router --> GoalsController' if @models.include?('team_goal')
    connections
  end

  def module_router_connections
    connections = []
    connections += competitive_router_connections
    connections += scrims_router_connections
    connections += strategy_router_connections
    connections += support_router_connections
    connections
  end

  def competitive_router_connections
    return [] unless @modules.include?('competitive')

    ['    Router --> CompetitiveController', '    Router --> ProMatchesController']
  end

  def scrims_router_connections
    return [] unless @modules.include?('scrims')

    ['    Router --> ScrimsController', '    Router --> OpponentTeamsController']
  end

  def strategy_router_connections
    connections = []
    connections << '    Router --> DraftPlansController' if @models.include?('draft_plan')
    connections << '    Router --> TacticalBoardsController' if @models.include?('tactical_board')
    connections
  end

  def support_router_connections
    return [] unless @models.include?('support_ticket')

    [
      '    Router --> SupportTicketsController',
      '    Router --> SupportFaqsController',
      '    Router --> SupportStaffController'
    ]
  end

  def generate_data_connections
    connections = auth_and_player_data_connections +
                  scouting_and_match_data_connections +
                  module_data_connections +
                  redis_data_connections
    connections.join("\n")
  end

  def auth_and_player_data_connections
    connections = []
    if @modules.include?('authentication')
      connections << '    AuthController --> JWTService'
      connections << '    AuthController --> UserModel'
    end
    if @models.include?('player')
      connections << '    PlayersController --> PlayerModel'
      connections << '    PlayerModel --> ChampionPoolModel' if @models.include?('champion_pool')
    end
    connections
  end

  def scouting_and_match_data_connections
    connections = []
    if @models.include?('scouting_target')
      connections += ['    ScoutingController --> ScoutingTargetModel',
                      '    ScoutingController --> Watchlist',
                      '    Watchlist --> PostgreSQL']
    end
    if @models.include?('match')
      connections << '    MatchesController --> MatchModel'
      connections << '    MatchModel --> PlayerMatchStatModel' if @models.include?('player_match_stat')
    end
    connections << '    SchedulesController --> ScheduleModel' if @models.include?('schedule')
    if @models.include?('vod_review')
      connections << '    VODController --> VodReviewModel'
      connections << '    VodReviewModel --> VodTimestampModel' if @models.include?('vod_timestamp')
    end
    connections << '    GoalsController --> TeamGoalModel' if @models.include?('team_goal')
    connections
  end

  def module_data_connections
    connections = []
    if has_analytics_routes?
      connections += ['    AnalyticsController --> PerformanceService',
                      '    AnalyticsController --> KDAService']
    end
    if @modules.include?('competitive')
      connections += ['    CompetitiveController --> PandaScoreService',
                      '    CompetitiveController --> DraftAnalyzer']
    end
    if @modules.include?('scrims')
      connections += ['    ScrimsController --> ScrimAnalytics',
                      '    ScrimAnalytics --> PostgreSQL']
    end
    connections << '    DraftPlansController --> DraftAnalysisService' if @models.include?('draft_plan')
    if @models.include?('support_ticket')
      connections += ['    SupportTicketsController --> SupportTicketModel',
                      '    SupportFaqsController --> SupportFaqModel',
                      '    SupportStaffController --> UserModel']
    end
    connections
  end

  def database_model_connections
    # Models already defined in subgraphs should not be redefined
    models_in_modules = %w[
      user player champion_pool scouting_target match player_match_stat
      schedule vod_review vod_timestamp team_goal support_ticket support_faq
      draft_plan tactical_board scrim opponent_team support_ticket_message
    ]

    @models.reject { |model| models_in_modules.include?(model) }.map do |model|
      model_name = model.split('_').map(&:capitalize).join
      "    #{model_name}Model[#{model_name} Model] --> PostgreSQL"
    end
  end

  def redis_data_connections
    connections = []
    connections << '    JWTService --> Redis' if @modules.include?('authentication')
    connections << '    DashStats --> Redis' if has_dashboard_routes?
    connections << '    PerformanceService --> Redis' if has_analytics_routes?
    connections
  end

  def generate_external_connections
    connections = []

    # Riot API connections
    if has_riot_integration?
      connections << '    PlayersController --> RiotService'
      connections << '    MatchesController --> RiotService'
      connections << '    ScoutingController --> RiotService'
      connections << '    RiotService --> RiotSync'
      connections << '    RiotService --> RiotAPI'
      connections << ''
      connections << '    RiotService --> Sidekiq'
    end

    # PandaScore connections
    connections << '    PandaScoreService --> PandaScoreAPI[PandaScore API]' if @modules.include?('competitive')

    # Sidekiq connections (simplified)
    connections << '    Sidekiq -- Uses --> Redis' if has_riot_integration?

    connections.compact.join("\n")
  end

  def has_dashboard_routes?
    routes_path = RAILS_ROOT.join('config', 'routes.rb').realpath
    validate_path_within_project(routes_path)
    routes_content = File.read(routes_path)
    routes_content.include?('dashboard')
  end

  def has_analytics_routes?
    routes_path = RAILS_ROOT.join('config', 'routes.rb').realpath
    validate_path_within_project(routes_path)
    routes_content = File.read(routes_path)
    routes_content.include?('analytics')
  end

  def has_riot_integration?
    gemfile_path = RAILS_ROOT.join('Gemfile').realpath
    validate_path_within_project(gemfile_path)
    gemfile = File.read(gemfile_path)
    gemfile.include?('faraday') || @services.values.any? { |s| s.include?('riot') }
  end

  def validate_path_within_project(path)
    rails_root_realpath = RAILS_ROOT.realpath
    return if path.to_s.start_with?(rails_root_realpath.to_s)

    raise SecurityError, "Path is outside project root: #{path}"
  end

  def update_readme(diagram)
    readme_realpath = README_PATH.realpath
    validate_path_within_project(readme_realpath)

    content = File.read(readme_realpath)
    arch_start = content.index('## Architecture')
    return unless arch_start

    arch_end = content.index(/^## /, arch_start + 1) || content.length
    new_content = content[0...arch_start] + architecture_section_text(diagram) + content[arch_end..]
    File.write(readme_realpath, new_content)
  end

  def architecture_section_text(diagram)
    <<~ARCH
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
      - `competitive` - PandaScore integration, pro matches, draft analysis
      - `scrims` - Scrim management and opponent team tracking
      - `strategy` - Draft planning and tactical board system
      - `support` - Support ticket system with staff and FAQ management

      ### Architecture Diagram

      #{diagram}

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

    ARCH
  end

  def export_mermaid_file(diagram)
    # Extract just the mermaid code (remove the markdown code fence)
    mermaid_code = diagram.strip.gsub(/^```mermaid\n/, '').gsub(/\n```$/, '')

    # Validate and write to diagram.mmd file
    diagram_path = RAILS_ROOT.join('diagram.mmd')
    diagram_realpath = diagram_path.expand_path
    validate_path_within_project(diagram_realpath)

    File.write(diagram_realpath, mermaid_code)
    puts '📄 Exported standalone diagram to diagram.mmd'
  end
end

# Run the generator
ArchitectureDiagramGenerator.new.run
