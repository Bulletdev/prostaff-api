# frozen_string_literal: true

# Adds captain draft support to the inhouse system.
#
# Inhouse status flow with draft:
#   waiting → draft (start_draft assigns captains)
#   draft   → in_progress (start_game after picks are done)
#   in_progress → done (close)
#
# Inhouses table:
#   blue_captain_id   — player who captains the blue team during draft
#   red_captain_id    — player who captains the red team during draft
#   draft_pick_number — 0-based index into PICK_ORDER (0..7); nil before draft
#   formation_mode    — 'auto' | 'captain_draft'; nil before any balancing action
#
# InhouseParticipations table:
#   is_captain        — true if this player is a draft captain
#
class AddCaptainDraftToInhouses < ActiveRecord::Migration[7.2]
  def change
    add_column :inhouses, :blue_captain_id,   :uuid
    add_column :inhouses, :red_captain_id,    :uuid
    add_column :inhouses, :draft_pick_number, :integer
    add_column :inhouses, :formation_mode,    :string

    add_foreign_key :inhouses, :players, column: :blue_captain_id
    add_foreign_key :inhouses, :players, column: :red_captain_id

    add_column :inhouse_participations, :is_captain, :boolean, default: false, null: false
  end
end
