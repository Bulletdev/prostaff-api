# frozen_string_literal: true

# Middleware para monitorar e logar atividades de bots
class BotLoggerMiddleware
  KNOWN_BOTS = %w[
    googlebot bingbot yandex duckduckbot applebot baiduspider
    twitterbot facebookexternalhit linkedinbot slackbot discordbot
    ahrefsbot semrushbot mj12bot dotbot rogerbot siteexplorer
    gptbot chatgpt ccbot anthropic-ai claude-web perplexitybot
    screaming frog seo spider
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    user_agent = request.user_agent.to_s.downcase

    # Detectar se é um bot
    bot_type = detect_bot(user_agent)

    if bot_type
      log_bot_activity(request, bot_type)
    end

    @app.call(env)
  end

  private

  def detect_bot(user_agent)
    return nil if user_agent.blank?

    KNOWN_BOTS.each do |bot|
      return bot if user_agent.include?(bot)
    end

    # Detectar bots genéricos
    return 'unknown_bot' if user_agent =~ /bot|crawler|spider|scraper/i

    nil
  end

  def log_bot_activity(request, bot_type)
    log_data = {
      timestamp: Time.current.iso8601,
      bot_type: bot_type,
      ip: request.ip,
      path: request.path,
      method: request.request_method,
      user_agent: request.user_agent,
      referer: request.referer
    }

    # Logar apenas em production ou se variável estiver habilitada
    return unless Rails.env.production? || ENV['LOG_BOT_ACTIVITY'] == 'true'

    Rails.logger.info "[Bot Activity] #{log_data.to_json}"

    # Salvar em arquivo separado se configurado
    if ENV['BOT_LOG_FILE']
      bot_log_file = Rails.root.join('log', 'bots.log')
      File.open(bot_log_file, 'a') do |f|
        f.puts log_data.to_json
      end
    end

    # Enviar para Redis para análise posterior (opcional)
    if ENV['REDIS_URL'] && ENV['TRACK_BOT_STATS'] == 'true'
      track_bot_stats(bot_type, request.path)
    end
  rescue StandardError => e
    Rails.logger.error "[BotLogger Error] #{e.message}"
  end

  def track_bot_stats(bot_type, path)
    redis = Redis.new(url: ENV['REDIS_URL'])
    date = Date.current.strftime('%Y-%m-%d')

    # Incrementar contador de bots por tipo
    redis.hincrby("bot_stats:#{date}", bot_type, 1)

    # Incrementar contador de caminhos acessados
    redis.hincrby("bot_paths:#{date}:#{bot_type}", path, 1)

    # Expirar após 30 dias
    redis.expire("bot_stats:#{date}", 30.days.to_i)
    redis.expire("bot_paths:#{date}:#{bot_type}", 30.days.to_i)
  rescue StandardError => e
    Rails.logger.error "[BotLogger Redis Error] #{e.message}"
  end
end
