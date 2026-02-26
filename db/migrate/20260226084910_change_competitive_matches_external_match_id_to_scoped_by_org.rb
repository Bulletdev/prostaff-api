# frozen_string_literal: true

# Replaces the global unique index on external_match_id with a composite
# unique index on (organization_id, external_match_id), allowing the same
# professional match to be imported independently for each organization.
#
# Previously, importing the same CBLOL match for "paiN Gaming" after it had
# already been imported for another org would fail because external_match_id
# was globally unique across all organizations.
class ChangeCompetitiveMatchesExternalMatchIdToScopedByOrg < ActiveRecord::Migration[7.2]
  def up
    remove_index :competitive_matches, :external_match_id
    add_index :competitive_matches, %i[organization_id external_match_id],
              unique: true,
              name: 'index_competitive_matches_on_org_and_external_match_id'
  end

  def down
    remove_index :competitive_matches,
                 name: 'index_competitive_matches_on_org_and_external_match_id'
    add_index :competitive_matches, :external_match_id,
              unique: true,
              name: 'index_competitive_matches_on_external_match_id'
  end
end
