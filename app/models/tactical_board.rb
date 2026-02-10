# frozen_string_literal: true

# TacticalBoard model
# Stores tactical positioning and annotations for match analysis
# Uses relative coordinates (0-100) for positioning to ensure consistency across devices
class TacticalBoard < ApplicationRecord
  # Concerns
  include OrganizationScoped

  # Associations
  belongs_to :organization
  belongs_to :match, optional: true
  belongs_to :scrim, optional: true
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validate :must_have_match_or_scrim
  validate :validate_map_state_structure
  validate :validate_annotations_structure

  # Callbacks
  after_update :log_audit_trail, if: :saved_changes?

  # Scopes
  scope :for_match, ->(match_id) { where(match_id: match_id) }
  scope :for_scrim, ->(scrim_id) { where(scrim_id: scrim_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_time, ->(time) { where('game_time LIKE ?', "%#{time}%") }

  # Instance methods

  # Add a player marker to the map
  # @param role [String] Player role (top, jungle, mid, adc, support)
  # @param champion [String] Champion name
  # @param x [Float] X coordinate (0-100)
  # @param y [Float] Y coordinate (0-100)
  # @param metadata [Hash] Additional data (health %, items, level, etc.)
  def add_player_marker(role:, champion:, x:, y:, metadata: {})
    validate_coordinates!(x, y)

    self.map_state ||= { 'players' => [] }
    self.map_state['players'] ||= []

    self.map_state['players'] << {
      'role' => role,
      'champion' => champion,
      'x' => x.to_f,
      'y' => y.to_f,
      'metadata' => metadata,
      'added_at' => Time.current.iso8601
    }
  end

  # Update player position
  # @param index [Integer] Index of the player in the array
  # @param x [Float] New X coordinate
  # @param y [Float] New Y coordinate
  def update_player_position(index, x:, y:)
    validate_coordinates!(x, y)

    return false unless map_state.dig('players', index)

    map_state['players'][index]['x'] = x.to_f
    map_state['players'][index]['y'] = y.to_f
    map_state['players'][index]['updated_at'] = Time.current.iso8601
    true
  end

  # Remove a player marker
  def remove_player_marker(index)
    return false unless map_state.dig('players', index)

    map_state['players'].delete_at(index)
  end

  # Add an annotation (arrow, text, area marker)
  # @param type [String] Type of annotation (arrow, text, circle, rectangle)
  # @param x [Float] X coordinate
  # @param y [Float] Y coordinate
  # @param options [Hash] Additional options (text, color, size, end_x, end_y for arrows)
  def add_annotation(type:, x:, y:, options: {})
    validate_coordinates!(x, y)

    self.annotations ||= []

    annotation = {
      'type' => type,
      'x' => x.to_f,
      'y' => y.to_f,
      'created_at' => Time.current.iso8601
    }.merge(options.stringify_keys)

    # Validate end coordinates for arrows
    if type == 'arrow' && options[:end_x] && options[:end_y]
      validate_coordinates!(options[:end_x], options[:end_y])
      annotation['end_x'] = options[:end_x].to_f
      annotation['end_y'] = options[:end_y].to_f
    end

    self.annotations << annotation
  end

  # Remove an annotation
  def remove_annotation(index)
    return false unless annotations[index]

    annotations.delete_at(index)
  end

  # Clear all player markers
  def clear_players
    self.map_state ||= {}
    self.map_state['players'] = []
  end

  # Clear all annotations
  def clear_annotations
    self.annotations = []
  end

  # Get all players on the map
  def players
    map_state&.dig('players') || []
  end

  # Get player by role
  def player_by_role(role)
    players.find { |p| p['role'] == role }
  end

  # Get statistics about the board
  def statistics
    {
      total_players: players.size,
      total_annotations: annotations&.size || 0,
      created_by_name: created_by&.name,
      last_updated: updated_at,
      game_time: game_time,
      linked_to: linked_entity
    }
  end

  # Generate a snapshot title based on context
  def auto_title
    entity = match || scrim
    return title if entity.nil?

    time_suffix = game_time.present? ? " @ #{game_time}" : ""
    "#{entity.class.name} ##{entity.id}#{time_suffix}"
  end

  private

  def must_have_match_or_scrim
    # Allow boards without match/scrim for standalone tactical planning
    # if match_id.blank? && scrim_id.blank?
    #   errors.add(:base, 'Must be linked to either a match or a scrim')
    # end

    return unless match_id.present? && scrim_id.present?

    errors.add(:base, 'Cannot be linked to both match and scrim')
  end

  def validate_map_state_structure
    return if map_state.blank?

    unless map_state.is_a?(Hash)
      errors.add(:map_state, 'must be a hash')
      return
    end

    return unless map_state['players']

    unless map_state['players'].is_a?(Array)
      errors.add(:map_state, 'players must be an array')
      return
    end

    map_state['players'].each_with_index do |player, index|
      validate_player_structure(player, index)
    end
  end

  def validate_player_structure(player, index)
    unless player.is_a?(Hash)
      errors.add(:map_state, "player at index #{index} must be a hash")
      return
    end

    unless player['x'].is_a?(Numeric) && player['y'].is_a?(Numeric)
      errors.add(:map_state, "player at index #{index} must have numeric x and y coordinates")
    end

    return unless player['x'] && player['y']

    unless (0..100).cover?(player['x']) && (0..100).cover?(player['y'])
      errors.add(:map_state, "player at index #{index} coordinates must be between 0 and 100")
    end
  end

  def validate_annotations_structure
    return if annotations.blank?

    unless annotations.is_a?(Array)
      errors.add(:annotations, 'must be an array')
      return
    end

    annotations.each_with_index do |annotation, index|
      validate_annotation_structure(annotation, index)
    end
  end

  def validate_annotation_structure(annotation, index)
    unless annotation.is_a?(Hash)
      errors.add(:annotations, "annotation at index #{index} must be a hash")
      return
    end

    unless annotation['type'] && annotation['x'] && annotation['y']
      errors.add(:annotations, "annotation at index #{index} must have type, x, and y")
    end

    return unless annotation['x'] && annotation['y']

    unless (0..100).cover?(annotation['x'].to_f) && (0..100).cover?(annotation['y'].to_f)
      errors.add(:annotations, "annotation at index #{index} coordinates must be between 0 and 100")
    end
  end

  def validate_coordinates!(x, y)
    unless x.is_a?(Numeric) && y.is_a?(Numeric)
      raise ArgumentError, 'Coordinates must be numeric'
    end

    return if (0..100).cover?(x) && (0..100).cover?(y)

    raise ArgumentError, 'Coordinates must be between 0 and 100'
  end

  def linked_entity
    return "Match ##{match_id}" if match_id.present?
    return "Scrim ##{scrim_id}" if scrim_id.present?

    'Unlinked'
  end

  def log_audit_trail
    AuditLog.create!(
      organization: organization,
      action: 'update',
      entity_type: 'TacticalBoard',
      entity_id: id,
      old_values: saved_changes.transform_values(&:first),
      new_values: saved_changes.transform_values(&:last)
    )
  end
end
