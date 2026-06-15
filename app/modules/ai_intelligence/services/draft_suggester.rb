# frozen_string_literal: true

# Suggests top-3 5th pick candidates for team_a given current state of the draft.
# Pool: champions that have appeared in competitive matches (stored in ai_champion_vectors).
# Uses WinProbabilityCalculator with a hypothetical 5th pick to score each candidate.
#
# Role coverage filter: when team_a already has 4 picks, champions whose primary role
# is already filled by one of those picks are excluded from the candidate pool.
# Unknown roles (not in CHAMPION_ROLES) are never excluded — conservative fallback.
#
# Performance note (A-04): iterates over all champions in the vector table.
# Acceptable for MVP given typical pool size (~80-150 champions). Monitor latency in prod.
class DraftSuggester
  CHAMPION_ROLES = {
    # Top
    'garen' => 'top', 'darius' => 'top', 'fiora' => 'top', 'camille' => 'top',
    'jax' => 'top', 'irelia' => 'top', 'gwen' => 'top', 'aatrox' => 'top',
    'riven' => 'top', 'jayce' => 'top', 'renekton' => 'top', 'ornn' => 'top',
    'malphite' => 'top', 'shen' => 'top', "k'sante" => 'top', 'ambessa' => 'top',
    'tryndamere' => 'top', 'yorick' => 'top', 'urgot' => 'top', 'volibear' => 'top',
    'mordekaiser' => 'top', 'illaoi' => 'top', 'sett' => 'top',
    # Jungle
    'lee sin' => 'jungle', 'vi' => 'jungle', 'graves' => 'jungle', 'nidalee' => 'jungle',
    'hecarim' => 'jungle', 'shyvana' => 'jungle', 'kindred' => 'jungle', 'viego' => 'jungle',
    'kayn' => 'jungle', "kha'zix" => 'jungle', 'evelynn' => 'jungle', 'elise' => 'jungle',
    'taliyah' => 'jungle', 'diana' => 'jungle', 'lillia' => 'jungle', 'udyr' => 'jungle',
    'xin zhao' => 'jungle', 'jarvan iv' => 'jungle', 'sejuani' => 'jungle',
    'wukong' => 'jungle', 'nocturne' => 'jungle', 'briar' => 'jungle',
    # Mid
    'azir' => 'mid', 'orianna' => 'mid', 'syndra' => 'mid', 'viktor' => 'mid',
    'ahri' => 'mid', 'zed' => 'mid', 'leblanc' => 'mid', 'ryze' => 'mid',
    'twisted fate' => 'mid', 'kassadin' => 'mid', 'akali' => 'mid',
    'galio' => 'mid', 'corki' => 'mid', 'aurora' => 'mid', 'hwei' => 'mid',
    'vex' => 'mid', 'lissandra' => 'mid', 'zoe' => 'mid', 'qiyana' => 'mid',
    'tristana' => 'mid', 'fizz' => 'mid', 'ekko' => 'mid',
    # ADC
    'jinx' => 'adc', "kai'sa" => 'adc', 'caitlyn' => 'adc', 'jhin' => 'adc',
    'aphelios' => 'adc', 'xayah' => 'adc', 'sivir' => 'adc', 'ezreal' => 'adc',
    'draven' => 'adc', 'lucian' => 'adc', 'varus' => 'adc', 'kalista' => 'adc',
    'ashe' => 'adc', 'miss fortune' => 'adc', 'zeri' => 'adc', 'samira' => 'adc',
    'smolder' => 'adc', 'nilah' => 'adc',
    # Support
    'thresh' => 'support', 'nautilus' => 'support', 'leona' => 'support', 'blitzcrank' => 'support',
    'lulu' => 'support', 'janna' => 'support', 'nami' => 'support', 'soraka' => 'support',
    'yuumi' => 'support', 'karma' => 'support', 'seraphine' => 'support', 'senna' => 'support',
    'bard' => 'support', 'rakan' => 'support', 'milio' => 'support', 'rell' => 'support',
    'braum' => 'support', 'lux' => 'support', 'morgana' => 'support', 'pyke' => 'support',
    'tahm kench' => 'support', 'taric' => 'support', 'zilean' => 'support'
  }.freeze

  def self.call(team_a:, team_b:, bans: [])
    new(team_a:, team_b:, bans:).suggest
  end

  def suggest
    taken  = (@team_a + @team_b + @bans).to_set { |c| c.downcase }
    filled = filled_roles
    rank_candidates(filter_candidates(taken, filled)).first(3).map { |r| r[:champion] }
  end

  private

  def initialize(team_a:, team_b:, bans: [])
    @team_a = team_a
    @team_b = team_b
    @bans   = Array(bans).map(&:downcase)
  end

  def filter_candidates(taken, filled)
    available_champions
      .reject { |champ| taken.include?(champ.downcase) }
      .reject { |champ| role_covered?(champ, filled) }
  end

  def rank_candidates(candidates)
    candidates
      .map     { |champ| { champion: champ, score: score_with(champ) } }
      .sort_by { |r| -r[:score] }
  end

  def filled_roles
    return Set.new unless @team_a.size >= 4

    @team_a.filter_map { |champ| CHAMPION_ROLES[champ.downcase] }.to_set
  end

  def role_covered?(champion, filled)
    return false if filled.empty?

    role = CHAMPION_ROLES[champion.downcase]
    role.present? && filled.include?(role)
  end

  def available_champions
    @available_champions ||= AiChampionVector.pluck(:champion_name)
  end

  def score_with(candidate)
    hypothetical_team = @team_a + [candidate]
    WinProbabilityCalculator.call(
      team_a: hypothetical_team,
      team_b: @team_b,
      synergies: {},
      counters: {}
    )[:score]
  end
end
