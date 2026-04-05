# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :riot do
  desc 'Update Data Dragon cache (champions, items, etc.)'
  task update_data_dragon: :environment do
    puts '🔄 Updating Data Dragon cache...'

    service = DataDragonService.new

    begin
      # Clear existing cache
      puts '🗑️  Clearing old cache...'
      service.clear_cache!

      # Fetch latest version
      puts '📦 Fetching latest game version...'
      version = service.latest_version
      puts "   ✅ Latest version: #{version}"

      # Fetch champion data
      puts '🎮 Fetching champion data...'
      champions = service.champion_id_map
      puts "   ✅ Loaded #{champions.count} champions"

      # Fetch all champions details
      puts '📊 Fetching detailed champion data...'
      all_champions = service.all_champions
      puts "   ✅ Loaded details for #{all_champions.count} champions"

      # Fetch items
      puts '⚔️  Fetching items data...'
      items = service.items
      puts "   ✅ Loaded #{items.count} items"

      # Fetch summoner spells
      puts '✨ Fetching summoner spells...'
      spells = service.summoner_spells
      puts "   ✅ Loaded #{spells.count} summoner spells"

      # Fetch profile icons
      puts '🖼️  Fetching profile icons...'
      icons = service.profile_icons
      puts "   ✅ Loaded #{icons.count} profile icons"

      puts "\n✅ Data Dragon cache updated successfully!"
      puts "   Version: #{version}"
      puts '   Cache will expire in 1 week'
    rescue StandardError => e
      puts "\n❌ Error updating Data Dragon cache: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc 'Show Data Dragon cache info'
  task cache_info: :environment do
    service = DataDragonService.new

    puts '📊 Data Dragon Cache Information'
    puts '=' * 50

    begin
      version = service.latest_version
      champions = service.champion_id_map
      all_champions = service.all_champions
      items = service.items
      spells = service.summoner_spells
      icons = service.profile_icons

      puts "Game Version:     #{version}"
      puts "Champions:        #{champions.count}"
      puts "Champion Details: #{all_champions.count}"
      puts "Items:            #{items.count}"
      puts "Summoner Spells:  #{spells.count}"
      puts "Profile Icons:    #{icons.count}"

      puts "\nSample Champions:"
      champions.first(5).each do |id, name|
        puts "  [#{id}] #{name}"
      end
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  desc 'Clear Data Dragon cache'
  task clear_cache: :environment do
    puts '🗑️  Clearing Data Dragon cache...'

    service = DataDragonService.new
    service.clear_cache!

    puts '✅ Cache cleared successfully!'
  end

  desc 'Sync all active players from Riot API'
  task sync_all_players: :environment do
    puts '🔄 Syncing all active players from Riot API...'

    Player.unscoped_by_organization.active.find_each do |player|
      puts "  Syncing #{player.summoner_name} (#{player.id}) from org #{player.organization_id}..."
      SyncPlayerFromRiotJob.perform_later(player.id, player.organization_id)
    end

    puts "✅ Queued #{Player.unscoped_by_organization.active.count} players for sync!"
  end

  desc 'Sync all scouting targets from Riot API'
  task sync_all_scouting_targets: :environment do
    puts '🔄 Syncing all scouting targets from Riot API...'

    ScoutingTarget.unscoped_by_organization.find_each do |target|
      puts "  Syncing #{target.summoner_name} (#{target.id}) from org #{target.organization_id}..."
      SyncScoutingTargetJob.perform_later(target.id, target.organization_id)
    end

    puts "✅ Queued #{ScoutingTarget.unscoped_by_organization.count} scouting targets for sync!"
  end
end
# rubocop:enable Metrics/BlockLength
