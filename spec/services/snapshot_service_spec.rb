require "rails_helper"

describe SnapshotService do
  class ExampleSnapshotSerializer
    def initialize(thing_to_snapshot)
      @thing_to_snapshot = thing_to_snapshot
    end

    def as_json
      @thing_to_snapshot.as_json.except("created_at", "updated_at")
    end
  end

  subject(:service) { described_class.new(paper, registry) }
  let(:paper) { FactoryGirl.create(:paper, :with_creator, :submitted) }
  let(:registry) { SnapshotService::Registry.new }
  let(:things_to_snapshot) { FactoryGirl.create_list(:ad_hoc_task, 3) }
  let(:snapshots) { Snapshot.all.order('id') }
  let(:adhoc_attachment) do
    FactoryGirl.create(:adhoc_attachment, :with_task, paper: paper)
  end

  before do
    registry.serialize things_to_snapshot[0].class, with: ExampleSnapshotSerializer
    registry.serialize adhoc_attachment.class, with: ExampleSnapshotSerializer
  end

  describe '.snapshot_paper!' do
    it 'snapshots the snapshottable things on the paper' do
      allow(paper).to receive(:snapshottable_things).and_return [
        things_to_snapshot.first, adhoc_attachment
      ]
      expect do
        SnapshotService.snapshot_paper!(paper, registry)
      end.to change { Snapshot.where(paper_id: paper.id).count }.by(2)
    end
  end

  describe '#snapshot!' do
    it "sets the source of each snapshot to the thing snapshotted" do
      service.snapshot!(things_to_snapshot)

      snapshots.zip(things_to_snapshot) do |snapshot, thing|
        expect(snapshot.source).to eq(thing)
      end
    end

    it "sets the contents of each snapshot to the JSON returned by the snapshot serializer" do
      service.snapshot!(things_to_snapshot)

      snapshots.zip(things_to_snapshot) do |snapshot, thing|
        expect(snapshot.contents).to eq(thing.as_json.except("created_at", "updated_at"))
      end
    end

    it "ties each snapshot back to the paper" do
      service.snapshot!(things_to_snapshot)

      snapshots.each do |snapshot|
        expect(snapshot.paper).to eq(paper)
      end
    end

    it "saves the major and minor version of the paper" do
      allow(paper).to receive(:major_version).and_return 4
      allow(paper).to receive(:minor_version).and_return 1

      service.snapshot!(things_to_snapshot)

      snapshots.each do |snapshot|
        expect(snapshot.major_version).to eq(4)
        expect(snapshot.minor_version).to eq(1)
      end
    end

    it 'creates a snapshot for each thing provided' do
      expect do
        service.snapshot!(things_to_snapshot)
      end.to change(Snapshot, :count).by(things_to_snapshot.length)
    end
  end

  describe '#preview' do
    it "does not set the major and minor version of the paper" do
      service.preview(things_to_snapshot).each do |snapshot|
        expect(snapshot.major_version).to be_nil
        expect(snapshot.minor_version).to be_nil
      end
    end
  end
end
