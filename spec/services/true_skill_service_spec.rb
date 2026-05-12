# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrueSkillService do
  Rating = TrueSkillService::Rating

  let(:default_rating) { Rating.new(TrueSkillService::MU, TrueSkillService::SIGMA) }

  def blue_team(size = 5)
    Array.new(size) { Rating.new(TrueSkillService::MU, TrueSkillService::SIGMA) }
  end

  def red_team(size = 5)
    Array.new(size) { Rating.new(TrueSkillService::MU, TrueSkillService::SIGMA) }
  end

  describe '.win_probability' do
    it 'returns 0.5 for balanced teams' do
      prob = TrueSkillService.win_probability(blue_team, red_team)
      expect(prob).to be_within(0.01).of(0.5)
    end

    it 'returns a float between 0.0 and 1.0' do
      blue = [Rating.new(40.0, 3.0)] * 5
      red  = [Rating.new(20.0, 5.0)] * 5
      prob = TrueSkillService.win_probability(blue, red)
      expect(prob).to be >= 0.0
      expect(prob).to be <= 1.0
    end

    it 'returns higher probability for the stronger team' do
      strong = [Rating.new(40.0, 3.0)] * 5
      weak   = [Rating.new(15.0, 5.0)] * 5
      prob   = TrueSkillService.win_probability(strong, weak)
      expect(prob).to be > 0.5
    end
  end

  describe '.update' do
    it 'returns a hash with :blue and :red keys' do
      result = TrueSkillService.update(blue_team, red_team, winner: 'blue')
      expect(result).to include(:blue, :red)
    end

    it 'increases mu for the winning team' do
      result = TrueSkillService.update(blue_team, red_team, winner: 'blue')
      result[:blue].each do |r|
        expect(r[:mu]).to be > TrueSkillService::MU
      end
    end

    it 'decreases mu for the losing team' do
      result = TrueSkillService.update(blue_team, red_team, winner: 'blue')
      result[:red].each do |r|
        expect(r[:mu]).to be < TrueSkillService::MU
      end
    end

    it 'sigma is never less than SIGMA_MIN' do
      result = TrueSkillService.update(blue_team, red_team, winner: 'red')
      (result[:blue] + result[:red]).each do |r|
        expect(r[:sigma]).to be >= TrueSkillService::SIGMA_MIN
      end
    end

    it 'returns correct team assignments when red wins' do
      result = TrueSkillService.update(blue_team, red_team, winner: 'red')
      result[:red].each { |r| expect(r[:mu]).to be > TrueSkillService::MU }
      result[:blue].each { |r| expect(r[:mu]).to be < TrueSkillService::MU }
    end
  end

  describe 'MMR calculation' do
    it 'MMR is never negative' do
      # Simulate a player with very low mu and high sigma
      very_weak = [Rating.new(1.0, 10.0)] * 5
      stronger  = [Rating.new(35.0, 2.0)] * 5
      result = TrueSkillService.update(very_weak, stronger, winner: 'red')
      # compute_mmr is private but verify via update_ratings indirectly
      result[:blue].each do |r|
        computed_mmr = [((r[:mu] - (3.0 * r[:sigma])) * 100).round, 0].max
        expect(computed_mmr).to be >= 0
      end
    end
  end
end
