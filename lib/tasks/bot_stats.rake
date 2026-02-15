# frozen_string_literal: true

namespace :bot_stats do
  desc 'Show bot activity statistics'
  task show: :environment do
    unless ENV['REDIS_URL'] && ENV['TRACK_BOT_STATS'] == 'true'
      puts '  Bot stats tracking is not enabled.'
      puts '   Set REDIS_URL and TRACK_BOT_STATS=true in your environment'
      exit
    end

    redis = Redis.new(url: ENV['REDIS_URL'])
    date = Date.current.strftime('%Y-%m-%d')

    puts " Bot Activity Statistics for #{date}"
    puts '=' * 60

    # Get bot counts
    bot_stats = redis.hgetall("bot_stats:#{date}")

    if bot_stats.empty?
      puts '   No bot activity recorded today.'
      exit
    end

    # Sort by count (descending)
    sorted_bots = bot_stats.sort_by { |_k, v| -v.to_i }

    puts "\n Bot Visits:"
    sorted_bots.each do |bot_type, count|
      puts "   #{bot_type.ljust(30)} #{count.to_s.rjust(6)} visits"
    end

    total_visits = bot_stats.values.map(&:to_i).sum
    puts "\n   #{'Total Bot Visits'.ljust(30)} #{total_visits.to_s.rjust(6)}"

    # Show top paths for each bot
    puts "\n Top Paths Accessed:"
    sorted_bots.first(5).each do |bot_type, _count|
      paths = redis.hgetall("bot_paths:#{date}:#{bot_type}")
      next if paths.empty?

      puts "\n   #{bot_type.capitalize}:"
      sorted_paths = paths.sort_by { |_k, v| -v.to_i }.first(5)
      sorted_paths.each do |path, visits|
        puts "     #{path.ljust(40)} #{visits} visits"
      end
    end

    puts "\n" + '=' * 60
  end

  desc 'Show bot statistics for date range'
  task :range, %i[start_date end_date] => :environment do |_t, args|
    unless ENV['REDIS_URL'] && ENV['TRACK_BOT_STATS'] == 'true'
      puts '  Bot stats tracking is not enabled.'
      exit
    end

    start_date = args[:start_date] ? Date.parse(args[:start_date]) : 7.days.ago.to_date
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.current

    redis = Redis.new(url: ENV['REDIS_URL'])

    puts " Bot Activity Statistics from #{start_date} to #{end_date}"
    puts '=' * 60

    aggregated_stats = Hash.new(0)

    (start_date..end_date).each do |date|
      date_str = date.strftime('%Y-%m-%d')
      bot_stats = redis.hgetall("bot_stats:#{date_str}")

      bot_stats.each do |bot_type, count|
        aggregated_stats[bot_type] += count.to_i
      end
    end

    if aggregated_stats.empty?
      puts '   No bot activity recorded in this period.'
      exit
    end

    sorted_bots = aggregated_stats.sort_by { |_k, v| -v }

    puts "\n Total Bot Visits:"
    sorted_bots.each do |bot_type, count|
      puts "   #{bot_type.ljust(30)} #{count.to_s.rjust(6)} visits"
    end

    total_visits = aggregated_stats.values.sum
    puts "\n   #{'Total Bot Visits'.ljust(30)} #{total_visits.to_s.rjust(6)}"
    puts "\n" + '=' * 60
  end

  desc 'Clear old bot statistics (older than 30 days)'
  task cleanup: :environment do
    unless ENV['REDIS_URL'] && ENV['TRACK_BOT_STATS'] == 'true'
      puts '  Bot stats tracking is not enabled.'
      exit
    end

    redis = Redis.new(url: ENV['REDIS_URL'])
    cutoff_date = 30.days.ago.to_date

    puts " Cleaning up bot statistics older than #{cutoff_date}"

    deleted_count = 0
    (cutoff_date - 90.days..cutoff_date).each do |date|
      date_str = date.strftime('%Y-%m-%d')

      if redis.exists?("bot_stats:#{date_str}")
        redis.del("bot_stats:#{date_str}")
        deleted_count += 1
      end

      # Clean up path stats too
      redis.keys("bot_paths:#{date_str}:*").each do |key|
        redis.del(key)
      end
    end

    puts " Cleaned up #{deleted_count} old stat entries"
  end
end
