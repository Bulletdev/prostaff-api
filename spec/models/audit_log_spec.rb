# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_presence_of(:entity_type) }
  end

  describe '.log_action' do
    it 'creates an audit log with correct fields' do
      # AuditLog includes OrganizationScoped whose default_scope blocks count queries
      # when Current.organization_id is nil. Use unscoped to count persisted records.
      expect {
        AuditLog.log_action(
          organization: organization,
          user: user,
          action: 'update',
          entity_type: 'Player',
          entity_id: SecureRandom.uuid,
          old_values: { 'status' => 'inactive' },
          new_values: { 'status' => 'active' },
          ip: '127.0.0.1',
          user_agent: 'RSpec/1.0'
        )
      }.to change { AuditLog.unscoped.count }.by(1)
    end

    it 'stores the action correctly' do
      log = AuditLog.log_action(
        organization: organization,
        action: 'delete',
        entity_type: 'Match'
      )
      expect(log.action).to eq('delete')
      expect(log.entity_type).to eq('Match')
      expect(log.organization).to eq(organization)
    end

    it 'allows a nil user for system actions' do
      expect {
        AuditLog.log_action(
          organization: organization,
          user: nil,
          action: 'system_sync',
          entity_type: 'Player'
        )
      }.not_to raise_error
    end

    it 'stores old_values and new_values as jsonb' do
      log = AuditLog.log_action(
        organization: organization,
        action: 'update',
        entity_type: 'Player',
        old_values: { 'role' => 'top' },
        new_values: { 'role' => 'mid' }
      )
      persisted = AuditLog.unscoped.find(log.id)
      expect(persisted.old_values).to eq('role' => 'top')
      expect(persisted.new_values).to eq('role' => 'mid')
    end
  end

  describe '#risk_level' do
    it 'returns high for delete action' do
      log = build(:audit_log, organization: organization, action: 'delete')
      expect(log.risk_level).to eq('high')
    end

    it 'returns low for create action' do
      log = build(:audit_log, organization: organization, action: 'create')
      expect(log.risk_level).to eq('low')
    end

    it 'returns info for login action' do
      log = build(:audit_log, organization: organization, action: 'login')
      expect(log.risk_level).to eq('info')
    end

    it 'returns medium for update action' do
      log = build(:audit_log, organization: organization, action: 'update')
      expect(log.risk_level).to eq('medium')
    end
  end

  describe '#user_display' do
    it 'returns user full_name when user is present' do
      log = build(:audit_log, organization: organization, user: user)
      expect(log.user_display).to eq(user.full_name)
    end

    it 'returns System when user is nil' do
      log = build(:audit_log, :login_action, organization: organization, user: nil)
      expect(log.user_display).to eq('System')
    end
  end

  describe '#changes_summary' do
    it 'returns Created for create action' do
      log = build(:audit_log, organization: organization, action: 'create')
      expect(log.changes_summary).to eq('Created')
    end

    it 'returns Deleted for delete action' do
      log = build(:audit_log, organization: organization, action: 'delete')
      expect(log.changes_summary).to eq('Deleted')
    end

    it 'describes changed fields for update action' do
      log = build(
        :audit_log, :update_action,
        organization: organization,
        action: 'update',
        old_values: { 'status' => 'inactive' },
        new_values: { 'status' => 'active' }
      )
      expect(log.changes_summary).to include('Status')
    end
  end

  describe 'scopes' do
    # AuditLog includes OrganizationScoped with a default_scope that applies
    # where('1=0') when Current.organization_id is nil. All scope queries must
    # start from unscoped to bypass it in tests.
    let!(:create_log)  { create(:audit_log, :create_action,  organization: organization, user: user) }
    let!(:update_log)  { create(:audit_log, :update_action,  organization: organization, user: user) }
    let!(:login_log)   { create(:audit_log, :login_action,   organization: organization, user: user) }

    def org_logs
      AuditLog.unscoped.where(organization_id: organization.id)
    end

    describe '.by_action' do
      it 'filters by action' do
        expect(org_logs.by_action('create')).to include(create_log)
        expect(org_logs.by_action('create')).not_to include(update_log)
      end
    end

    describe '.by_user' do
      it 'filters by user_id' do
        other_user = create(:user, organization: organization)
        other_log  = create(:audit_log, organization: organization, user: other_user, action: 'create', entity_type: 'Player')
        expect(org_logs.by_user(user.id)).to include(create_log)
        expect(org_logs.by_user(user.id)).not_to include(other_log)
      end
    end

    describe '.security_events' do
      it 'returns login and logout actions' do
        expect(org_logs.security_events).to include(login_log)
        expect(org_logs.security_events).not_to include(update_log)
      end
    end

    describe '.high_risk_actions' do
      it 'includes delete action' do
        delete_log = create(:audit_log, :destroy_action, organization: organization, user: user, action: 'delete')
        expect(org_logs.high_risk_actions).to include(delete_log)
        expect(org_logs.high_risk_actions).not_to include(update_log)
      end
    end
  end

  describe '#ip_location' do
    it 'returns Local for 127.0.0.1' do
      log = build(:audit_log, organization: organization, ip_address: '127.0.0.1')
      expect(log.ip_location).to eq('Local')
    end

    it 'returns Private Network for 192.168.x.x' do
      log = build(:audit_log, organization: organization, ip_address: '192.168.1.100')
      expect(log.ip_location).to eq('Private Network')
    end

    it 'returns External for a public IP' do
      log = build(:audit_log, organization: organization, ip_address: '8.8.8.8')
      expect(log.ip_location).to eq('External')
    end

    it 'returns Unknown when ip_address is blank' do
      log = build(:audit_log, organization: organization, ip_address: nil)
      expect(log.ip_location).to eq('Unknown')
    end
  end
end
