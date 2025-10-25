# frozen_string_literal: true

# Abstract base class for all application models
#
# This class serves as the primary abstract class for all models in the application,
# inheriting from ActiveRecord::Base. All application models should inherit from this
# class rather than directly from ActiveRecord::Base.
#
# @abstract Subclass and add model-specific behavior
# @example Define a new model
#   class MyModel < ApplicationRecord
#     # model code here
#   end
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
