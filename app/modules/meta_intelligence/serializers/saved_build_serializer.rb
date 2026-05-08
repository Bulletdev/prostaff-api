# frozen_string_literal: true

# Blueprinter serializer for SavedBuild model.
#
# Formats build data for API responses including performance metrics,
# item/rune arrays, and display-friendly computed fields.
#
# @example Render a single build
#   SavedBuildSerializer.render_as_hash(build)
#
# @example Render a collection
#   SavedBuildSerializer.render_as_hash(builds, root: :builds)
class SavedBuildSerializer < Blueprinter::Base
  identifier :id

  fields :champion, :role, :patch_version, :title, :notes,
         :is_public, :data_source, :games_played,
         :items, :item_build_order, :trinket,
         :runes, :primary_rune_tree, :secondary_rune_tree,
         :summoner_spell_1, :summoner_spell_2,
         :created_at, :updated_at

  field :win_rate do |build, _options|
    build.win_rate.to_f.round(2)
  end

  field :average_kda do |build, _options|
    build.average_kda.to_f.round(2)
  end

  field :average_cs_per_min do |build, _options|
    build.average_cs_per_min.to_f.round(2)
  end

  field :average_damage_share do |build, _options|
    build.average_damage_share.to_f.round(2)
  end

  field :win_rate_display do |build, _options|
    build.win_rate_display
  end

  field :created_by_id do |build, _options|
    build.created_by_id
  end
end
