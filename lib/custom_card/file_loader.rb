module CustomCard
  class FileLoader
    def initialize(journal)
      @journal = journal
      @cards = Set.new(journal.cards.map(&:name))
      @permissions = DefaultCardPermissions.new(journal)
      validate_configuration
      CardTaskType.seed_defaults
    end

    def load(paths = self.class.paths)
      Array(paths).each do |file_path|
        load_card(file_path)
      end
    end

    def load_card(file_path)
      file_name = self.class.base_name(file_path)
      name = file_name.titleize
      return if @cards.include?(name)

      xml = File.read(file_path)
      card = create_card(name, xml)
      set_permissions(card, file_name)
    end

    def self.all(journals: [])
      which_journals = Array(journals.presence || Journal.all)
      which_journals.each { |journal| load(journal) }
    end

    def self.load(journal)
      new(journal).load
    end

    def self.names
      paths.map { |file_path| base_name(file_path) }
    end

    private

    def validate_configuration
      @permissions.validate(self.class.names)
    end

    def create_card(card_name, xml)
      card_type = task_type(card_name)
      card = Card.create_initial_draft!(name: card_name, journal: @journal, card_task_type: card_type)
      card.update_from_xml(xml)
      card.reload.publish!('Initial Version')
      card
    end

    def set_permissions(card, file_name)
      @permissions.apply(file_name) do |action, roles|
        CardPermissions.set_roles(card, action, roles)
      end
    end

    def task_type(card_name)
      task_type = CardTaskType.named(card_name) || CardTaskType.custom_card
      raise(StandardError, "Cannot find card task type for #{card_name}") unless task_type
      task_type
    end

    private_class_method

    PATH = %w[lib custom_card configurations xml_content].freeze
    def self.paths
      home = Rails.root.join(*PATH)
      Dir["#{home}/*.xml"]
    end

    def self.base_name(file_name)
      File.basename(file_name, '.xml')
    end
  end
end