# frozen_string_literal: true

RSpec.shared_context 'cross-org isolation' do
  let(:other_org)  { create(:organization) }
  let(:other_user) { create(:user, :admin, organization: other_org) }
end
