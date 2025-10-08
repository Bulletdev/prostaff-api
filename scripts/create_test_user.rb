#!/usr/bin/env ruby

# Create test user for load testing

org = Organization.first

if org.nil?
  puts "❌ No organization found. Please create one first."
  exit 1
end

user = User.find_or_initialize_by(email: 'test@prostaff.gg')
if user.new_record?
  user.password = 'Test123!@#'
  user.password_confirmation = 'Test123!@#'
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
puts "Password:     Test123!@#"
puts "Organization: #{org.name}"
puts "Role:         #{user.role}"
puts "\nReady for load testing! 🚀"
