# frozen_string_literal: true

RSpec.shared_context 'authenticated admin' do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:headers)      { auth_headers(user) }
end
