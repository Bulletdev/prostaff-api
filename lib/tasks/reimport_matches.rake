# frozen_string_literal: true

namespace :matches do
  desc 'Reimport all existing matches to update missing data (CS, damage_share, etc)'
  task reimport_all: :environment do
    puts "Starting reimport of all matches..."
    
    organization_id = ENV['ORGANIZATION_ID']
    player_id = ENV['PLAYER_ID']
    
    if organization_id
      organization = Organization.find(organization_id)
      matches = organization.matches.includes(:player_match_stats)
      puts "Found #{matches.count} matches for organization #{organization.name}"
    elsif player_id
      player = Player.find(player_id)
      matches = player.matches.includes(:player_match_stats)
      puts "Found #{matches.count} matches for player #{player.summoner_name}"
    else
      matches = Match.includes(:player_match_stats).all
      puts "Found #{matches.count} matches across all organizations"
    end
    
    # Filter matches that need update
    matches_to_update = matches.select do |match|
      match.player_match_stats.any? do |stat|
        stat.cs.nil? || stat.cs.zero? ||
        stat.damage_share.nil? ||
        stat.gold_share.nil? ||
        stat.cs_per_min.nil?
      end
    end
    
    puts "Found #{matches_to_update.count} matches that need update"
    
    if matches_to_update.empty?
      puts "No matches need updating. Exiting."
      exit
    end
    
    # Ask for confirmation
    print "Do you want to proceed with reimporting #{matches_to_update.count} matches? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'yes' || confirmation == 'y'
      puts "Cancelled."
      exit
    end
    
    region = ENV['REGION'] || 'BR'
    updated = 0
    errors = 0
    
    matches_to_update.each_with_index do |match, index|
      begin
        puts "[#{index + 1}/#{matches_to_update.count}] Reimporting match #{match.riot_match_id}..."
        Matches::Jobs::SyncMatchJob.perform_now(match.riot_match_id, match.organization_id, region, true)
        updated += 1
        sleep(0.1) # Small delay to avoid rate limiting
      rescue StandardError => e
        puts "  Error: #{e.message}"
        errors += 1
      end
    end
    
    puts "\nReimport completed!"
    puts "  Updated: #{updated}"
    puts "  Errors: #{errors}"
  end
  
  desc 'Reimport matches for a specific player'
  task :reimport_player, [:player_id] => :environment do |_t, args|
    player_id = args[:player_id] || ENV['PLAYER_ID']
    
    unless player_id
      puts "Error: Player ID is required"
      puts "Usage: rake matches:reimport_player[player_id]"
      exit 1
    end
    
    player = Player.find(player_id)
    matches = player.matches.includes(:player_match_stats)
    
    puts "Found #{matches.count} matches for player #{player.summoner_name}"
    
    matches_to_update = matches.select do |match|
      match.player_match_stats.any? do |stat|
        stat.cs.nil? || stat.cs.zero? ||
        stat.damage_share.nil? ||
        stat.gold_share.nil? ||
        stat.cs_per_min.nil?
      end
    end
    
    puts "Found #{matches_to_update.count} matches that need update"
    
    if matches_to_update.empty?
      puts "No matches need updating."
      exit
    end
    
    region = player.region || 'BR'
    updated = 0
    errors = 0
    
    matches_to_update.each_with_index do |match, index|
      begin
        puts "[#{index + 1}/#{matches_to_update.count}] Reimporting match #{match.riot_match_id}..."
        Matches::Jobs::SyncMatchJob.perform_now(match.riot_match_id, match.organization_id, region, force_update: true)
        updated += 1
        sleep(0.1)
      rescue StandardError => e
        puts "  Error: #{e.message}"
        errors += 1
      end
    end
    
    puts "\nReimport completed!"
    puts "  Updated: #{updated}"
    puts "  Errors: #{errors}"
  end
end

