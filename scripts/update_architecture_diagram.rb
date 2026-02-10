#!/usr/bin/env ruby
# frozen_string_literal: true

# This script analyzes the Rails application structure and updates the architecture diagram
# in README.md with current modules, controllers, models, and services

require 'pathname'

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
    sections = []

    # Authentication module
    sections << generate_auth_module if @modules.include?('authentication')

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

    # New modules
    sections << generate_competitive_module if @modules.include?('competitive')
    sections << generate_scrims_module if @modules.include?('scrims')
    sections << generate_strategy_module if @models.include?('draft_plan') || @models.include?('tactical_board')
    sections << generate_support_module if @models.include?('support_ticket')

    sections.compact.join("\n\n")
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

    # Competitive module routes
    if @modules.include?('competitive')
      connections << '    Router --> CompetitiveController'
      connections << '    Router --> ProMatchesController'
    end

    # Scrims module routes
    if @modules.include?('scrims')
      connections << '    Router --> ScrimsController'
      connections << '    Router --> OpponentTeamsController'
    end

    # Strategy module routes
    if @models.include?('draft_plan') || @models.include?('tactical_board')
      connections << '    Router --> DraftPlansController' if @models.include?('draft_plan')
      connections << '    Router --> TacticalBoardsController' if @models.include?('tactical_board')
    end

    # Support module routes
    if @models.include?('support_ticket')
      connections << '    Router --> SupportTicketsController'
      connections << '    Router --> SupportFaqsController'
      connections << '    Router --> SupportStaffController'
    end

    connections.join("\n")
  end

  def generate_data_connections
    connections = []

    # Auth connections
    if @modules.include?('authentication')
      connections << '    AuthController --> JWTService'
      connections << '    AuthController --> UserModel'
    end

    # Players connections
    if @models.include?('player')
      connections << '    PlayersController --> PlayerModel'
      connections << '    PlayerModel --> ChampionPoolModel' if @models.include?('champion_pool')
    end

    # Scouting connections
    if @models.include?('scouting_target')
      connections << '    ScoutingController --> ScoutingTargetModel'
      connections << '    ScoutingController --> Watchlist'
      connections << '    Watchlist --> PostgreSQL'
    end

    # Matches connections
    if @models.include?('match')
      connections << '    MatchesController --> MatchModel'
      connections << '    MatchModel --> PlayerMatchStatModel' if @models.include?('player_match_stat')
    end

    # Other model connections
    connections << '    SchedulesController --> ScheduleModel' if @models.include?('schedule')

    if @models.include?('vod_review')
      connections << '    VODController --> VodReviewModel'
      connections << '    VodReviewModel --> VodTimestampModel' if @models.include?('vod_timestamp')
    end

    connections << '    GoalsController --> TeamGoalModel' if @models.include?('team_goal')

    # Analytics connections
    if has_analytics_routes?
      connections << '    AnalyticsController --> PerformanceService'
      connections << '    AnalyticsController --> KDAService'
    end

    # Competitive connections
    if @modules.include?('competitive')
      connections << '    CompetitiveController --> PandaScoreService'
      connections << '    CompetitiveController --> DraftAnalyzer'
    end

    # Scrims connections
    if @modules.include?('scrims')
      connections << '    ScrimsController --> ScrimAnalytics'
      connections << '    ScrimAnalytics --> PostgreSQL'
    end

    # Strategy connections
    if @models.include?('draft_plan')
      connections << '    DraftPlansController --> DraftAnalysisService'
    end

    # Support connections
    if @models.include?('support_ticket')
      connections << '    SupportTicketsController --> SupportTicketModel'
      connections << '    SupportFaqsController --> SupportFaqModel'
      connections << '    SupportStaffController --> UserModel'
    end

    # Database connections
    @models.each do |model|
      model_name = model.split('_').map(&:capitalize).join
      connections << "    #{model_name}Model[#{model_name} Model] --> PostgreSQL"
    end

    # Redis connections
    connections << '    JWTService --> Redis' if @modules.include?('authentication')
    connections << '    DashStats --> Redis' if has_dashboard_routes?
    connections << '    PerformanceService --> Redis' if has_analytics_routes?

    connections.join("\n")
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
    if @modules.include?('competitive')
      connections << '    PandaScoreService --> PandaScoreAPI[PandaScore API]'
    end

    # Sidekiq connections (simplified)
    if has_riot_integration?
      connections << '    Sidekiq -- Uses --> Redis'
    end

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
    unless path.to_s.start_with?(rails_root_realpath.to_s)
      raise SecurityError, "Path is outside project root: #{path}"
    end
  end

  def update_readme(diagram)
    # Validate README_PATH is within project root
    readme_realpath = README_PATH.realpath
    validate_path_within_project(readme_realpath)

    content = File.read(readme_realpath)

    # Find the architecture section
    arch_start = content.index('## Architecture')
    return unless arch_start

    # Find the end of architecture section (next ## heading or end of file)
    arch_end = content.index(/^## /, arch_start + 1) || content.length

    # Extract before and after sections
    before_arch = content[0...arch_start]
    after_arch = content[arch_end..]

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

    # Write back to file with validated path
    File.write(readme_realpath, before_arch + new_arch_section + after_arch)
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
