# frozen_string_literal: true

# By default Rails serializes BigDecimal as a String in JSON (e.g. "45.3") to avoid
# IEEE 754 float precision issues. This means ActiveRecord aggregate results like
# stats.average(:damage_share) come through the API as strings instead of numbers,
# which breaks frontend code that calls .toFixed() directly on the value.
#
# For analytics data (percentages, ratios, averages), float precision is perfectly
# acceptable. We override BigDecimal#as_json so it serializes as a numeric JSON value
# instead of a string, matching the frontend's expectation.

require 'bigdecimal'

class BigDecimal
  def as_json(_options = nil)
    to_f
  end
end
