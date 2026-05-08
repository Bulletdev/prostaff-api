# frozen_string_literal: true

# Collapse model directories inside modules so that models keep their
# original class names (e.g. Player, not Players::Player).
#
# Without collapse: app/modules/players/models/player.rb => Players::Models::Player
# With collapse:    app/modules/players/models/player.rb => Player
#
# The dual mechanism (root in application.rb + collapse here) is required for
# all layer dirs that need flat constant names. Without collapse, the broad
# 'app/modules' root (added first to autoload_paths) wins the resolution and
# derives Analytics::Services::Foo instead of the intended flat Foo.
Rails.autoloaders.main.tap do |loader|
  # Models — flat class names (Player, not Players::Models::Player)
  Dir[Rails.root.join('app/modules/*/models')].each do |path|
    loader.collapse(path) if File.directory?(path)
  end

  Dir[Rails.root.join('app/modules/*/models/concerns')].each do |path|
    loader.collapse(path) if File.directory?(path)
  end

  # Jobs — Module::JobName convention
  # (e.g. app/modules/players/jobs/sync_player_job.rb => Players::SyncPlayerJob)
  Dir[Rails.root.join('app/modules/*/jobs')].each do |path|
    loader.collapse(path) if File.directory?(path)
  end

  # Flat-named layers: serializers, policies, channels, services.
  # These cannot be registered via config.autoload_paths in application.rb
  # because Rails finalises Zeitwerk roots before that loop runs (only model
  # dirs added via the separate Dir[] block above application.rb get picked up).
  # Registering them here with push_dir, AFTER the loader is already set up,
  # is the reliable way to add subdirectory roots under 'app/modules'.
  # Zeitwerk will then use the most-specific (deepest) root for each file,
  # giving flat constant names: PlayerSerializer, JwtService, etc.
  %w[serializers policies channels services].each do |layer|
    Dir[Rails.root.join("app/modules/*/#{layer}")].each do |path|
      next unless File.directory?(path)

      loader.push_dir(path)
    end
  end
end
