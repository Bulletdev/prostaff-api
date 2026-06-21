# frozen_string_literal: true

module Manager
  # Serializer for StaffMember model.
  #
  # NOTE: the contract association is intentionally excluded to prevent infinite
  # serializer recursion: ContractSerializer embeds StaffMemberSerializer, and if
  # StaffMemberSerializer also embedded ContractSerializer the Blueprinter rendering
  # would loop until a SystemStackError is raised.
  # Contract details are available via the denormalized contract_start_date and
  # contract_end_date fields when a quick summary is needed.
  class StaffMemberSerializer < Blueprinter::Base
    identifier :id

    fields :name, :role, :status, :line, :country, :birth_date,
           :contract_start_date, :contract_end_date,
           :twitter_handle, :instagram_handle, :avatar_url,
           :notes, :created_at, :updated_at
  end
end
