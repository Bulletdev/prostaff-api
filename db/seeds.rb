# frozen_string_literal: true

# Seeds file for ProStaff API - Development/Testing Data
#
# SECURITY NOTE: This file creates development-only accounts
# Never use these credentials in production!

# Get password from ENV or use default for development
DEFAULT_DEV_PASSWORD = ENV.fetch('DEV_SEED_PASSWORD', 'password123')

puts '🌱 Seeding database with organizations...'

# ============================================================================
# TIME 1: Java E-sports (Tier 1 Professional)
# ============================================================================
puts "\n📍 Creating Java E-sports..."

org1 = Organization.find_or_create_by!(id: '043824c0-906f-4aa2-9bc7-11d668b508dc') do |organization|
  organization.name = 'Java E-sports'
  organization.slug = 'java-esports'
  organization.region = 'BR'
  organization.tier = 'tier_1_professional'
  organization.subscription_plan = 'professional'
  organization.subscription_status = 'active'
end

puts "   ✅ Organization: #{org1.name} (#{org1.tier})"

user1 = User.find_or_create_by!(email: 'coach@teamalpha.gg') do |user|
  user.organization = org1
  user.password = DEFAULT_DEV_PASSWORD
  user.password_confirmation = DEFAULT_DEV_PASSWORD
  user.full_name = 'Java E-sports Coach'
  user.role = 'coach'
  user.timezone = 'America/Sao_Paulo'
  user.language = 'pt-BR'
end

puts "   ✅ User: #{user1.email} (role: #{user1.role})"

# ============================================================================
# TIME 2: BotaPagodão.net (Tier 2 Semi-Pro)
# ============================================================================
puts "\n📍 Creating BotaPagodão.net..."

org2 = Organization.find_or_create_by!(id: 'd2e76113-eeda-4e5c-9a5e-bd3e944fc290') do |organization|
  organization.name = 'BotaPagodão.net'
  organization.slug = 'botapagodao-net'
  organization.region = 'BR'
  organization.tier = 'tier_2_semi_pro'
  organization.subscription_plan = 'semi_pro'
  organization.subscription_status = 'active'
end

puts "   ✅ Organization: #{org2.name} (#{org2.tier})"

user2 = User.find_or_create_by!(email: 'coach@botapagodao.net') do |user|
  user.organization = org2
  user.password = DEFAULT_DEV_PASSWORD
  user.password_confirmation = DEFAULT_DEV_PASSWORD
  user.full_name = 'BotaPagodão Coach'
  user.role = 'coach'
  user.timezone = 'America/Sao_Paulo'
  user.language = 'pt-BR'
end

puts "   ✅ User: #{user2.email} (role: #{user2.role})"

# ============================================================================
# TIME 3: Discordia (Tier 2 Semi-Pro)
# ============================================================================
puts "\n📍 Creating Discordia..."

org3 = Organization.find_or_create_by!(slug: 'discordia') do |organization|
  organization.name = 'Discordia'
  organization.region = 'BR'
  organization.tier = 'tier_2_semi_pro'
  organization.subscription_plan = 'semi_pro'
  organization.subscription_status = 'active'
end

puts "   ✅ Organization: #{org3.name} (#{org3.tier}) - ID: #{org3.id}"

user3 = User.find_or_create_by!(email: 'coach@discordia.gg') do |user|
  user.organization = org3
  user.password = DEFAULT_DEV_PASSWORD
  user.password_confirmation = DEFAULT_DEV_PASSWORD
  user.full_name = 'Discordia Coach'
  user.role = 'coach'
  user.timezone = 'America/Sao_Paulo'
  user.language = 'pt-BR'
end

puts "   ✅ User: #{user3.email} (role: #{user3.role})"

# ============================================================================
# SUMMARY
# ============================================================================
puts "\n" + ('=' * 70)
puts '🎉 Database seeded successfully!'
puts('=' * 70)
puts "\n📋 Organizations Created:"
puts '   1. Java E-sports (Tier 1 Professional)'
puts "      • ID: #{org1.id}"
puts "      • Login: coach@teamalpha.gg / #{DEFAULT_DEV_PASSWORD}"
puts ''
puts '   2. BotaPagodão.net (Tier 2 Semi-Pro)'
puts "      • ID: #{org2.id}"
puts "      • Login: coach@botapagodao.net / #{DEFAULT_DEV_PASSWORD}"
puts ''
puts '   3. Discordia (Tier 2 Semi-Pro)'
puts "      • ID: #{org3.id}"
puts "      • Login: coach@discordia.gg / #{DEFAULT_DEV_PASSWORD}"
puts "\n" + ('=' * 70)
puts '📝 Next Steps:'
puts '   • Import players manually for each organization'
puts '   • Verify login works with the credentials above'
puts "\n⚠️  IMPORTANT: These are DEVELOPMENT-ONLY credentials!"
puts '   Never use these passwords in production environments.'
puts ('=' * 70) + "\n"
