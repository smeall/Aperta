require 'rails_helper'

describe TaskType do
  after do
    TaskType.deregister(SampleTask)
  end

  describe ".register" do
    before do
      class SampleTask; end
    end

    it "will add to the list of task types" do
      TaskType.register(SampleTask, "title", "old_role")
      expect(TaskType.types.keys).to include("SampleTask")
    end
  end

  describe ".deregister" do
    before do
      class SampleTask; end
    end

    before do
      TaskType.register(SampleTask, "title", "old_role")
    end

    it "will remove the class from the list of registered task types" do
      TaskType.deregister(SampleTask)
      expect(TaskType.types.keys).to_not include("SampleTask")
    end
  end

  describe ".constantize!" do

    context "with a registered class" do
      before do
        class SampleTask; end
        TaskType.register(SampleTask, "title", "old_role")
      end

      it "constantizes" do
        expect(TaskType.constantize!("SampleTask")).to eq(SampleTask)
      end
    end

    context "without a registered class" do
      it "errors" do
        expect { TaskType.constantize!("NotASampleTask") }.to raise_error(RuntimeError, "NotASampleTask is not a registered TaskType")
      end
    end
  end

end
