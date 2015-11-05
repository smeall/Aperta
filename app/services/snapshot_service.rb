class SnapshotService
  def self.configure(&blk)
    registry.instance_eval(&blk)
  end

  def self.registry
    @registry ||= Registry.new
  end

  def initialize(paper, registry=SnapshotService.registry)
    @paper = paper
    @registry = registry
  end

  def snapshot!(*things_to_snapshot)
    things_to_snapshot.flatten.each do |thing|
      serializer_klass = @registry.serializer_for(thing)
      json = serializer_klass.new(thing).as_json
      Snapshot.create!(
        source: thing,
        contents: json,
        paper: @paper,
        major_version: @paper.major_version,
        minor_version: @paper.minor_version
      )
    end
  end
end
