# Seeds file for ProStaff API
# This file should contain all the record creation needed to seed the database with its default values.

puts "🌱 Seeding database..."

# Create sample organization
org = Organization.find_or_create_by!(slug: 'team-alpha') do |organization|
  organization.name = 'Team Alpha'
  organization.region = 'BR'
  organization.tier = 'semi_pro'
  organization.subscription_plan = 'pro'
  organization.subscription_status = 'active'
end

puts "✅ Created organization: #{org.name}"

# Create admin user
admin = User.find_or_create_by!(email: 'admin@teamalpha.gg') do |user|
  user.organization = org
  user.password = 'password123'
  user.full_name = 'Admin User'
  user.role = 'owner'
  user.timezone = 'America/Sao_Paulo'
  user.language = 'pt-BR'
end

puts "✅ Created admin user: #{admin.email}"

# Create coach user
coach = User.find_or_create_by!(email: 'coach@teamalpha.gg') do |user|
  user.organization = org
  user.password = 'password123'
  user.full_name = 'Head Coach'
  user.role = 'coach'
  user.timezone = 'America/Sao_Paulo'
  user.language = 'pt-BR'
end

puts "✅ Created coach user: #{coach.email}"

# Create analyst user
analyst = User.find_or_create_by!(email: 'analyst@teamalpha.gg') do |user|
  user.organization = org
  user.password = 'password123'
  user.full_name = 'Performance Analyst'
  user.role = 'analyst'
  user.timezone = 'America/Sao_Paulo'
  user.language = 'pt-BR'
end

puts "✅ Created analyst user: #{analyst.email}"

# Create sample players
players_data = [
  {
    summoner_name: 'AlphaTop',
    real_name: 'João Silva',
    role: 'top',
    country: 'BR',
    birth_date: Date.parse('2001-03-15'),
    solo_queue_tier: 'MASTER',
    solo_queue_rank: 'II',
    solo_queue_lp: 234,
    solo_queue_wins: 127,
    solo_queue_losses: 89,
    champion_pool: ['Garen', 'Darius', 'Sett', 'Renekton', 'Camille'],
    playstyle_tags: ['Tank', 'Engage', 'Team Fighter'],
    jersey_number: 1,
    contract_start_date: 1.year.ago,
    contract_end_date: 1.year.from_now,
    salary: 5000.00
  },
  {
    summoner_name: 'JungleKing',
    real_name: 'Pedro Santos',
    role: 'jungle',
    country: 'BR',
    birth_date: Date.parse('2000-08-22'),
    solo_queue_tier: 'GRANDMASTER',
    solo_queue_rank: 'I',
    solo_queue_lp: 456,
    solo_queue_wins: 189,
    solo_queue_losses: 112,
    champion_pool: ['Graves', 'Kindred', 'Nidalee', 'Elise', 'Kha\'Zix'],
    playstyle_tags: ['Carry', 'Aggressive', 'Counter Jungle'],
    jersey_number: 2,
    contract_start_date: 8.months.ago,
    contract_end_date: 16.months.from_now,
    salary: 7500.00
  },
  {
    summoner_name: 'MidLaner',
    real_name: 'Carlos Rodrigues',
    role: 'mid',
    country: 'BR',
    birth_date: Date.parse('1999-12-05'),
    solo_queue_tier: 'CHALLENGER',
    solo_queue_rank: nil,
    solo_queue_lp: 1247,
    solo_queue_wins: 234,
    solo_queue_losses: 145,
    champion_pool: ['Azir', 'Syndra', 'Orianna', 'Yasuo', 'LeBlanc'],
    playstyle_tags: ['Control Mage', 'Playmaker', 'Late Game'],
    jersey_number: 3,
    contract_start_date: 6.months.ago,
    contract_end_date: 18.months.from_now,
    salary: 10000.00
  },
  {
    summoner_name: 'ADCMain',
    real_name: 'Rafael Costa',
    role: 'adc',
    country: 'BR',
    birth_date: Date.parse('2002-01-18'),
    solo_queue_tier: 'MASTER',
    solo_queue_rank: 'I',
    solo_queue_lp: 567,
    solo_queue_wins: 156,
    solo_queue_losses: 98,
    champion_pool: ['Jinx', 'Caitlyn', 'Ezreal', 'Kai\'Sa', 'Aphelios'],
    playstyle_tags: ['Scaling', 'Positioning', 'Team Fight'],
    jersey_number: 4,
    contract_start_date: 10.months.ago,
    contract_end_date: 14.months.from_now,
    salary: 6000.00
  },
  {
    summoner_name: 'SupportGod',
    real_name: 'Lucas Oliveira',
    role: 'support',
    country: 'BR',
    birth_date: Date.parse('2001-07-30'),
    solo_queue_tier: 'MASTER',
    solo_queue_rank: 'III',
    solo_queue_lp: 345,
    solo_queue_wins: 143,
    solo_queue_losses: 107,
    champion_pool: ['Thresh', 'Nautilus', 'Leona', 'Braum', 'Alistar'],
    playstyle_tags: ['Engage', 'Vision Control', 'Shotcaller'],
    jersey_number: 5,
    contract_start_date: 4.months.ago,
    contract_end_date: 20.months.from_now,
    salary: 4500.00
  }
]

players_data.each do |player_data|
  player = Player.find_or_create_by!(
    organization: org,
    summoner_name: player_data[:summoner_name]
  ) do |p|
    player_data.each { |key, value| p.send("#{key}=", value) }
  end

  puts "✅ Created player: #{player.summoner_name} (#{player.role})"

  # Create champion pool entries for each player
  player.champion_pool.each_with_index do |champion, index|
    ChampionPool.find_or_create_by!(
      player: player,
      champion: champion
    ) do |cp|
      cp.games_played = rand(10..50)
      cp.games_won = (cp.games_played * (0.4 + rand * 0.4)).round
      cp.mastery_level = [5, 6, 7].sample
      cp.average_kda = 1.5 + rand * 2.0
      cp.average_cs_per_min = 6.0 + rand * 2.0
      cp.average_damage_share = 0.15 + rand * 0.15
      cp.is_comfort_pick = index < 2
      cp.is_pocket_pick = index == 2
      cp.priority = 10 - index
      cp.last_played = rand(30).days.ago
    end
  end
end

# Create sample matches
3.times do |i|
  match = Match.find_or_create_by!(
    organization: org,
    riot_match_id: "BR_MATCH_#{1000 + i}"
  ) do |m|
    m.match_type = ['official', 'scrim'].sample
    m.game_version = '14.19'
    m.game_start = (i + 1).days.ago
    m.game_duration = 1800 + rand(1200) # 30-50 minutes
    m.our_side = ['blue', 'red'].sample
    m.opponent_name = "Team #{['Beta', 'Gamma', 'Delta'][i]}"
    m.victory = [true, false].sample
    m.our_score = rand(5..25)
    m.opponent_score = rand(5..25)
    m.our_towers = rand(3..11)
    m.opponent_towers = rand(3..11)
    m.our_dragons = rand(0..4)
    m.opponent_dragons = rand(0..4)
    m.our_barons = rand(0..2)
    m.opponent_barons = rand(0..2)
  end

  puts "✅ Created match: #{match.opponent_name} (#{match.victory? ? 'Victory' : 'Defeat'})"

  # Create player stats for each match
  org.players.each do |player|
    PlayerMatchStat.find_or_create_by!(
      match: match,
      player: player
    ) do |stat|
      stat.champion = player.champion_pool.sample
      stat.role = player.role
      stat.kills = rand(0..15)
      stat.deaths = rand(0..10)
      stat.assists = rand(0..20)
      stat.cs = rand(150..300)
      stat.gold_earned = rand(10000..20000)
      stat.damage_dealt_champions = rand(15000..35000)
      stat.vision_score = rand(20..80)
      stat.items = Array.new(6) { rand(1000..4000) }
      stat.summoner_spell_1 = 'Flash'
      stat.summoner_spell_2 = ['Teleport', 'Ignite', 'Heal', 'Barrier'].sample
    end
  end
end

# Create sample scouting targets
scouting_targets_data = [
  {
    summoner_name: 'ProspectTop',
    region: 'BR',
    role: 'top',
    current_tier: 'GRANDMASTER',
    current_rank: 'II',
    current_lp: 678,
    champion_pool: ['Fiora', 'Jax', 'Irelia'],
    playstyle: 'aggressive',
    strengths: ['Mechanical skill', 'Lane dominance'],
    weaknesses: ['Team fighting', 'Communication'],
    status: 'watching',
    priority: 'high',
    added_by: admin
  },
  {
    summoner_name: 'YoungSupport',
    region: 'BR',
    role: 'support',
    current_tier: 'MASTER',
    current_rank: 'I',
    current_lp: 423,
    champion_pool: ['Pyke', 'Bard', 'Rakan'],
    playstyle: 'calculated',
    strengths: ['Vision control', 'Roaming'],
    weaknesses: ['Consistency', 'Champion pool'],
    status: 'contacted',
    priority: 'medium',
    added_by: coach
  }
]

scouting_targets_data.each do |target_data|
  target = ScoutingTarget.find_or_create_by!(
    organization: org,
    summoner_name: target_data[:summoner_name],
    region: target_data[:region]
  ) do |t|
    target_data.each { |key, value| t.send("#{key}=", value) }
  end

  puts "✅ Created scouting target: #{target.summoner_name} (#{target.role})"
end

# Create sample team goals
[
  {
    title: 'Reach Diamond Average Rank',
    description: 'Team average rank should be Diamond or higher',
    category: 'rank',
    metric_type: 'rank_climb',
    target_value: 6, # Diamond = 6
    current_value: 5, # Platinum = 5
    start_date: 1.month.ago,
    end_date: 2.months.from_now,
    assigned_to: coach,
    created_by: admin
  },
  {
    title: 'Improve Team KDA',
    description: 'Team should maintain above 2.0 KDA average',
    category: 'performance',
    metric_type: 'kda',
    target_value: 2.0,
    current_value: 1.7,
    start_date: 2.weeks.ago,
    end_date: 6.weeks.from_now,
    assigned_to: analyst,
    created_by: admin
  }
].each do |goal_data|
  goal = TeamGoal.find_or_create_by!(
    organization: org,
    title: goal_data[:title]
  ) do |g|
    goal_data.each { |key, value| g.send("#{key}=", value) }
  end

  puts "✅ Created team goal: #{goal.title}"
end

# Create individual player goals
org.players.limit(2).each_with_index do |player, index|
  goal_data = [
    {
      title: "Improve #{player.summoner_name} CS/min",
      description: "Target 8.0+ CS per minute average",
      category: 'skill',
      metric_type: 'cs_per_min',
      target_value: 8.0,
      current_value: 6.5,
      player: player
    },
    {
      title: "Increase #{player.summoner_name} Vision Score",
      description: "Target 2.5+ vision score per minute",
      category: 'performance',
      metric_type: 'vision_score',
      target_value: 2.5,
      current_value: 1.8,
      player: player
    }
  ][index]

  goal = TeamGoal.find_or_create_by!(
    organization: org,
    player: player,
    title: goal_data[:title]
  ) do |g|
    goal_data.each { |key, value| g.send("#{key}=", value) }
    g.start_date = 1.week.ago
    g.end_date = 8.weeks.from_now
    g.assigned_to = coach
    g.created_by = admin
  end

  puts "✅ Created player goal: #{goal.title}"
end

puts "\n🎉 Database seeded successfully!"
puts "\n📋 Summary:"
puts "   • Organization: #{org.name}"
puts "   • Users: #{org.users.count}"
puts "   • Players: #{org.players.count}"
puts "   • Matches: #{org.matches.count}"
puts "   • Scouting Targets: #{org.scouting_targets.count}"
puts "   • Team Goals: #{org.team_goals.count}"
puts "\n🔐 Login credentials:"
puts "   • Admin: admin@teamalpha.gg / password123"
puts "   • Coach: coach@teamalpha.gg / password123"
puts "   • Analyst: analyst@teamalpha.gg / password123"