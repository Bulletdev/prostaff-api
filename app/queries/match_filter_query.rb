# frozen_string_literal: true

# Applies filtering and sorting to a pre-scoped Match relation.
#
# Accepts an ActiveRecord relation already scoped to an organization and a
# params hash, then chains every supported filter and the final sort order.
# Pagination is intentionally excluded and remains the caller's responsibility.
#
# @example
#   matches = organization_scoped(Match).includes(:player_match_stats, :players)
#   MatchFilterQuery.new(matches, params).call
class MatchFilterQuery
  ALLOWED_SORT_FIELDS  = %w[game_start game_duration match_type victory created_at].freeze
  ALLOWED_SORT_ORDERS  = %w[asc desc].freeze
  DEFAULT_SORT_FIELD   = 'game_start'
  DEFAULT_SORT_ORDER   = 'desc'

  # @param relation [ActiveRecord::Relation] organization-scoped Match relation
  # @param params   [ActionController::Parameters, Hash] request parameters
  def initialize(relation, params)
    @relation = relation
    @params   = params
  end

  # Applies all filters and sort order, returning the resulting relation.
  #
  # @return [ActiveRecord::Relation]
  def call
    result = apply_basic_filters(@relation)
    result = apply_date_filters(result)
    result = apply_opponent_filter(result)
    result = apply_tournament_filter(result)
    apply_sorting(result)
  end

  private

  def apply_basic_filters(matches)
    matches = matches.by_type(@params[:match_type]) if @params[:match_type].present?
    matches = matches.victories                      if @params[:result] == 'victory'
    matches = matches.defeats                        if @params[:result] == 'defeat'
    matches
  end

  def apply_date_filters(matches)
    if @params[:start_date].present? && @params[:end_date].present?
      matches.in_date_range(@params[:start_date], @params[:end_date])
    elsif @params[:days].present?
      matches.recent(@params[:days].to_i)
    else
      matches
    end
  end

  def apply_opponent_filter(matches)
    return matches unless @params[:opponent].present?

    matches.with_opponent(@params[:opponent])
  end

  def apply_tournament_filter(matches)
    return matches unless @params[:tournament].present?

    matches.where('tournament_name ILIKE ?', "%#{@params[:tournament]}%")
  end

  def apply_sorting(matches)
    sort_by    = ALLOWED_SORT_FIELDS.include?(@params[:sort_by])    ? @params[:sort_by]    : DEFAULT_SORT_FIELD
    sort_order = ALLOWED_SORT_ORDERS.include?(@params[:sort_order]) ? @params[:sort_order] : DEFAULT_SORT_ORDER

    matches.order(sort_by => sort_order)
  end
end
