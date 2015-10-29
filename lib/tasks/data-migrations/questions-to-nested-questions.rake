namespace 'data:migrate:questions-to-nested-questions' do
  DATA_MIGRATION_QUESTION_RAKE_TASKS = %w(
    authors
    competing-interests
    data-availability
    ethics
    figures
    financial-disclosure
    plos-billing
    publishing-related-questions
    reporting-guidelines
    reviewer-recommendations
    reviewer-report
    taxon
    plos-bio-initial-tech-check
    plos-bio-revision-tech-check
    plos-bio-final-tech-check
  )

  task environment: '^environment' do
    NestedQuestionAnswer.disable_owner_verification = true
  end

  desc "Calls :reset task for all question-to-nested-question(s)"
  task reset_all: 'data:migrate:questions-to-nested-questions:environment' do
    tasks_as_strings = DATA_MIGRATION_QUESTION_RAKE_TASKS.map do |t|
      ["data:migrate:questions-to-nested-questions:#{t}:reset"]
    end.flatten
    tasks_as_strings.each do |task_as_string|
      Rake::Task[task_as_string].invoke
    end
  end

  desc "Runs the migrations for all question-to-nested-question(s)"
  task migrate_all: 'data:migrate:questions-to-nested-questions:environment' do
    tasks_as_strings = DATA_MIGRATION_QUESTION_RAKE_TASKS.map do |t|
      ["data:migrate:questions-to-nested-questions:#{t}"]
    end.flatten
    tasks_as_strings.each do |task_as_string|
      Rake::Task[task_as_string].invoke
    end
  end

  namespace :authors do
    desc "Resets the NestedQuestionAnswer(s) for authors by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::AuthorsQuestionsMigrator.reset
    end

    desc "Destroy old questions for authors once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::AuthorsQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the authors task data to the NestedQuestion data model."
  task authors: 'data:migrate:questions-to-nested-questions:authors:reset' do
    DataMigrator::AuthorsQuestionsMigrator.migrate!
  end

  namespace :'competing-interests' do
    desc "Resets the NestedQuestionAnswer(s) for competing interests by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::CompetingInterestsQuestionsMigrator.reset
    end

    desc "Destroy old questions for competing interests once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::CompetingInterestsQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the competing interests task data to the NestedQuestion data model."
  task 'competing-interests': 'data:migrate:questions-to-nested-questions:data-availability:reset' do
    DataMigrator::CompetingInterestsQuestionsMigrator.migrate!
  end

  namespace :'data-availability' do
    desc "Resets the NestedQuestionAnswer(s) for data availability by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::DataAvailabilityQuestionsMigrator.reset
    end

    desc "Destroy old questions for data availability once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::DataAvailabilityQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the data availability task data to the NestedQuestion data model."
  task 'data-availability': 'data:migrate:questions-to-nested-questions:data-availability:reset' do
    DataMigrator::DataAvailabilityQuestionsMigrator.migrate!
  end

  namespace :ethics do
    desc "Resets the NestedQuestionAnswer(s) for ethics by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::EthicsQuestionsMigrator.reset
    end

    desc "Destroy old questions for ethics once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::EthicsQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the ethics task data to the NestedQuestion data model."
  task ethics: 'data:migrate:questions-to-nested-questions:ethics:reset' do
    DataMigrator::EthicsQuestionsMigrator.migrate!
  end

  namespace :figures do
    desc "Resets the NestedQuestionAnswer(s) for figures by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::FigureQuestionsMigrator.reset
    end

    desc "Destroy old questions for figures once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::FigureQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the figures task data to the NestedQuestion data model."
  task figures: 'data:migrate:questions-to-nested-questions:figures:reset' do
    DataMigrator::FigureQuestionsMigrator.migrate!
  end

  namespace :'financial-disclosure' do
    desc "Resets the NestedQuestionAnswer(s) for financial-disclosure by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::FinancialDisclosureQuestionsMigrator.reset
    end

    desc "Destroy old questions for financial-disclosure once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::FinancialDisclosureQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the financial-disclosure task data to the NestedQuestion data model."
  task 'financial-disclosure': 'data:migrate:questions-to-nested-questions:financial-disclosure:reset' do
    DataMigrator::FinancialDisclosureQuestionsMigrator.migrate!
  end

  namespace :'plos-billing' do
    desc "Resets the NestedQuestionAnswer(s) for plos-billing by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBillingQuestionsMigrator.reset
    end

    desc "Destroy old questions for plos-billing once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBillingQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the plos-billing task data to the NestedQuestion data model."
  task 'plos-billing': 'data:migrate:questions-to-nested-questions:plos-billing:reset' do
    DataMigrator::PlosBillingQuestionsMigrator.migrate!
  end

  namespace :'publishing-related-questions' do
    desc "Resets the NestedQuestionAnswer(s) for publishing-related-questions by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PublishingRelatedQuestionsMigrator.reset
    end

    desc "Destroy old questions for publishing-related-questions once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PublishingRelatedQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the publishing-related-questions task data to the NestedQuestion data model."
  task 'publishing-related-questions': 'data:migrate:questions-to-nested-questions:publishing-related-questions:reset' do
    DataMigrator::PublishingRelatedQuestionsMigrator.migrate!
  end

  namespace :taxon do
    desc "Resets the NestedQuestionAnswer(s) for figures by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::TaxonQuestionsMigrator.reset
    end

    desc "Destroy old questions for figures once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::TaxonQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the taxon task data to the NestedQuestion data model."
  task taxon: 'data:migrate:questions-to-nested-questions:taxon:reset' do
    DataMigrator::TaxonQuestionsMigrator.migrate!
  end

  namespace :'reporting-guidelines' do
    desc "Resets the NestedQuestionAnswer(s) for reporting-guidelines by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::ReportingGuidelinesQuestionsMigrator.reset
    end

    desc "Destroy old questions for reporting guidelines once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::ReportingGuidelinesQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the reporting guidelines task data to the NestedQuestion data model."
  task 'reporting-guidelines': 'data:migrate:questions-to-nested-questions:reporting-guidelines:reset' do
    DataMigrator::ReportingGuidelinesQuestionsMigrator.migrate!
  end

  namespace :'reviewer-recommendations' do
    desc "Resets the NestedQuestionAnswer(s) for figures by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::ReviewerRecommendationsQuestionsMigrator.reset
    end

    desc "Destroy old questions for revieewer recommendations once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::ReviewerRecommendationsQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the reviewer-recommendations task data to the NestedQuestion data model."
  task 'reviewer-recommendations': 'data:migrate:questions-to-nested-questions:reviewer-recommendations:reset' do
    DataMigrator::ReviewerRecommendationsQuestionsMigrator.migrate!
  end


  namespace :'reviewer-report' do
    desc "Resets the NestedQuestionAnswer(s) for figures by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::ReviewerReportQuestionsMigrator.reset
    end

    desc "Destroy old questions for revieewer report once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::ReviewerReportQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the reviewer-report task data to the NestedQuestion data model."
  task 'reviewer-report': 'data:migrate:questions-to-nested-questions:reviewer-report:reset' do
    DataMigrator::ReviewerReportQuestionsMigrator.migrate!
  end

  namespace :'plos-bio-initial-tech-check' do
    desc "Resets the NestedQuestionAnswer(s) for plos-bio-tech-check by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBioInitialTechCheckQuestionsMigrator.reset
    end

    desc "Destroy old questions for plos-bio-initial-tech-check once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBioInitialTechCheckQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the plos-bio-initial-tech-check task data to the NestedQuestion data model."
  task 'plos-bio-initial-tech-check': 'data:migrate:questions-to-nested-questions:plos-bio-initial-tech-check:reset' do
    DataMigrator::PlosBioInitialTechCheckQuestionsMigrator.migrate!
  end

  namespace :'plos-bio-revision-tech-check' do
    desc "Resets the NestedQuestionAnswer(s) for plos-bio-revision-tech-check by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBioRevisionTechCheckQuestionsMigrator.reset
    end

    desc "Destroy old questions for plos-bio-revision-tech-check once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBioRevisionTechCheckQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the plos-bio-revision-tech-check task data to the NestedQuestion data model."
  task 'plos-bio-revision-tech-check': 'data:migrate:questions-to-nested-questions:plos-bio-revision-tech-check:reset' do
    DataMigrator::PlosBioRevisionTechCheckQuestionsMigrator.migrate!
  end

  namespace :'plos-bio-final-tech-check' do
    desc "Resets the NestedQuestionAnswer(s) for plos-bio-final-tech-check by destroying them."
    task reset: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBioFinalTechCheckQuestionsMigrator.reset
    end

    desc "Destroy old questions for plos-bio-final-tech-check once you're satisfied w/migrating to NestedQuestion data model."
    task cleanup: 'data:migrate:questions-to-nested-questions:environment' do
      DataMigrator::PlosBioFinalTechCheckQuestionsMigrator.cleanup
    end
  end

  desc "Migrate the plos-bio-final-tech-check task data to the NestedQuestion data model."
  task 'plos-bio-final-tech-check': 'data:migrate:questions-to-nested-questions:plos-bio-final-tech-check:reset' do
    DataMigrator::PlosBioFinalTechCheckQuestionsMigrator.migrate!
  end
end