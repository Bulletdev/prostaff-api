#!/usr/bin/env ruby

# Create test user for load testing

org = Organization.first

if org.nil?
  puts "❌ No organization found. Please create one first."
  exit 1
end

# brakeman:ignore:HardcodedSecret
test_email = ENV['TEST_EMAIL'] || 'test@prostaff.gg'
# brakeman:ignore:HardcodedSecret
test_password = ENV['TEST_PASSWORD'] || 'Test123!@#'

user = User.find_or_initialize_by(email: test_email)
if user.new_record?
  user.password = test_password
  user.password_confirmation = test_password
  user.organization = org
  user.role = 'admin'
  user.save!
  puts '✅ Test user created!'
else
  puts '✅ Test user already exists!'
end

puts "\nTest Credentials:"
puts "=================="
puts "Email:        #{user.email}"
puts "Password:     #{test_password.gsub(/./, '*')}"
puts "Organization: #{org.name}"
puts "Role:         #{user.role}"
puts "\nReady for load testing! 🚀"
