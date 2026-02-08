# frozen_string_literal: true

namespace :trial do
  desc 'Expire organizations with expired trials'
  task expire: :environment do
    puts ' Checking for expired trials...'

    expired_orgs = Organization.trial_expired

    if expired_orgs.empty?
      puts ' No expired trials found.'
    else
      count = 0
      expired_orgs.find_each do |org|
        org.expire_trial!
        puts "   Expired trial for: #{org.name} (expired on #{org.trial_expires_at})"
        count += 1

        # Send notification email to owner
        owner = org.users.find_by(role: 'owner')
        UserMailer.trial_expired(owner).deliver_later if owner.present?
      end

      puts " Expired #{count} trial(s)."
    end
  end

  desc 'Send warning emails for trials expiring soon (3 days)'
  task warn_expiring: :environment do
    puts ' Checking for trials expiring soon...'

    expiring_soon = Organization.trial_active.where('trial_expires_at <= ?', 3.days.from_now)

    if expiring_soon.empty?
      puts ' No trials expiring soon.'
    else
      count = 0
      expiring_soon.find_each do |org|
        days_remaining = org.trial_days_remaining
        puts "    Trial expiring soon for: #{org.name} (#{days_remaining} days remaining)"

        # Send warning email to owner
        owner = org.users.find_by(role: 'owner')
        if owner.present?
          UserMailer.trial_expiring_soon(owner, days_remaining).deliver_later
          count += 1
        end
      end

      puts " Sent #{count} warning email(s)."
    end
  end

  desc 'Show trial statistics'
  task stats: :environment do
    puts ' Trial Statistics'
    puts '=' * 50

    total_orgs = Organization.count
    active_trials = Organization.trial_active.count
    expired_trials = Organization.where(subscription_status: 'expired').count
    active_subscriptions = Organization.where(subscription_status: 'active').count
    expiring_soon = Organization.trial_active.where('trial_expires_at <= ?', 3.days.from_now).count

    puts "Total Organizations:     #{total_orgs}"
    puts "Active Trials:           #{active_trials}"
    puts "Active Subscriptions:    #{active_subscriptions}"
    puts "Expired Trials:          #{expired_trials}"
    puts "Expiring Soon (3 days):  #{expiring_soon}"
    puts '=' * 50

    if active_trials > 0
      puts "\nActive Trials:"
      Organization.trial_active.find_each do |org|
        puts "  - #{org.name}: #{org.trial_days_remaining} days remaining"
      end
    end
  end
end
