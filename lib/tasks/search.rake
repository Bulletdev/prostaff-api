# frozen_string_literal: true

namespace :search do
  SEARCHABLE_MODELS = [Player, Organization, ScoutingTarget, OpponentTeam, SupportFaq].freeze

  desc 'Configure Meilisearch index settings and reindex all searchable models'
  task reindex: :environment do
    unless MEILISEARCH_CLIENT
      puts '  MEILISEARCH_URL not set — aborting reindex'
      exit 1
    end

    SEARCHABLE_MODELS.each do |model|
      print "→ Reindexing #{model.name}… "
      model.meili_reindex!
      puts "#{model.count} documents"
    end

    puts '  Reindex complete'
  end

  desc 'Configure index settings only (searchable + filterable attributes), without reindexing data'
  task configure: :environment do
    unless MEILISEARCH_CLIENT
      puts '  MEILISEARCH_URL not set — aborting'
      exit 1
    end

    SEARCHABLE_MODELS.each do |model|
      index = MEILISEARCH_CLIENT.index(model.meili_index_name)
      index.update_settings(
        searchable_attributes: model.meili_searchable_attributes,
        filterable_attributes: model.meili_filterable_attributes
      )
      puts "→ Configured #{model.meili_index_name}"
    end

    puts '  Configuration applied'
  end

  desc 'Show document count per index'
  task stats: :environment do
    unless MEILISEARCH_CLIENT
      puts '  MEILISEARCH_URL not set'
      exit 1
    end

    SEARCHABLE_MODELS.each do |model|
      index = MEILISEARCH_CLIENT.index(model.meili_index_name)
      puts "#{model.meili_index_name.ljust(20)} #{index.number_of_documents} docs"
    rescue StandardError => e
      puts "#{model.meili_index_name.ljust(20)} error: #{e.message}"
    end
  end
end
