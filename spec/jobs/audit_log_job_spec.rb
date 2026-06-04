# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLogJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:entity_id)    { SecureRandom.uuid }

  # AuditLog includes OrganizationScoped which applies a default_scope filtered
  # by Current.organization_id. Use unscoped_by_organization for counting in
  # specs where Current is not set by the test itself.
  def audit_count
    AuditLog.unscoped_by_organization.count
  end

  def last_audit_log
    AuditLog.unscoped_by_organization.order(created_at: :asc).last
  end

  describe '#perform' do
    context 'when all required parameters are provided' do
      it 'creates an AuditLog record' do
        expect do
          described_class.new.perform(
            organization_id: organization.id,
            entity_type: 'Player',
            entity_id: entity_id,
            old_values: { 'status' => 'inactive' },
            new_values: { 'status' => 'active' }
          )
        end.to change { audit_count }.by(1)
      end

      it 'persists the correct attribute values' do
        described_class.new.perform(
          organization_id: organization.id,
          entity_type: 'Player',
          entity_id: entity_id,
          old_values: { 'status' => 'inactive' },
          new_values: { 'status' => 'active' }
        )

        log = last_audit_log
        expect(log.organization_id).to eq(organization.id)
        expect(log.action).to eq('update')
        expect(log.entity_type).to eq('Player')
        expect(log.entity_id).to eq(entity_id)
        expect(log.old_values).to eq({ 'status' => 'inactive' })
        expect(log.new_values).to eq({ 'status' => 'active' })
        expect(log.user_id).to be_nil
      end

      it 'persists the optional user_id when supplied' do
        described_class.new.perform(
          organization_id: organization.id,
          entity_type: 'Player',
          entity_id: entity_id,
          old_values: {},
          new_values: { 'name' => 'updated' },
          user_id: user.id
        )

        expect(last_audit_log.user_id).to eq(user.id)
      end

      it 'clears Current.organization_id after execution' do
        described_class.new.perform(
          organization_id: organization.id,
          entity_type: 'Match',
          entity_id: entity_id,
          old_values: {},
          new_values: {}
        )

        expect(Current.organization_id).to be_nil
      end
    end

    context 'when AuditLog.create! raises an error' do
      it 'propagates the error so Sidekiq can retry (up to sidekiq_options retry: 3)' do
        allow(AuditLog).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(AuditLog.new))

        expect do
          described_class.new.perform(
            organization_id: organization.id,
            entity_type: 'Player',
            entity_id: entity_id,
            old_values: {},
            new_values: {}
          )
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'still clears Current.organization_id even when an error is raised' do
        allow(AuditLog).to receive(:create!).and_raise(StandardError, 'db error')

        begin
          described_class.new.perform(
            organization_id: organization.id,
            entity_type: 'Player',
            entity_id: entity_id,
            old_values: {},
            new_values: {}
          )
        rescue StandardError
          nil
        end

        expect(Current.organization_id).to be_nil
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
