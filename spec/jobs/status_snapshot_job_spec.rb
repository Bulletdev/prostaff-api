# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatusSnapshotJob, type: :job do
  describe '#perform' do
    context 'on the normal path' do
      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end

      it 'creates a StatusSnapshot record for each component' do
        component_count = StatusIncident::COMPONENTS.size
        expect {
          described_class.new.perform
        }.to change { StatusSnapshot.count }.by(component_count)
      end

      it 'persists only valid component names' do
        described_class.new.perform

        snapshots = StatusSnapshot.order(created_at: :asc).last(StatusIncident::COMPONENTS.size)
        components = snapshots.map(&:component)
        components.each do |component|
          expect(StatusIncident::COMPONENTS).to include(component)
        end
      end

      it 'persists a valid status string for each snapshot' do
        described_class.new.perform

        valid_statuses = %w[operational degraded_performance major_outage]
        StatusSnapshot.all.each do |snap|
          expect(valid_statuses).to include(snap.status),
            "unexpected status '#{snap.status}' for component '#{snap.component}'"
        end
      end
    end

    context 'when StatusSnapshot.create! raises for one component' do
      before do
        call_count = 0
        allow(StatusSnapshot).to receive(:create!) do |args|
          call_count += 1
          raise ActiveRecord::RecordInvalid.new(StatusSnapshot.new) if call_count == 1

          StatusSnapshot.new(args).tap(&:save!)
        end
      end

      it 'does not raise (error is rescued per component)' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context 'job configuration' do
      it 'uses the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
