require 'csv'

module PlosServices
  class BillingLogManager

    def initialize(paper:)
      @paper = paper
    end

    def paper_to_billing_log_hash
      {
        guid:                          'PONE-2', # @paper.creator.em_guid, when em_guid is merged
        document_id:                   @paper.manuscript_id,
        title:                         answer_for('title'),
        first_name:                    answer_for('first_name'),
        middlename:                    '',
        lastname:                      answer_for('last_name'),
        institute:                     'placeholderInstitute',
        department:                    'placeholderDepartment',
        address1:                      answer_for('address1'),
        address2:                      answer_for('address2'),
        address3:                      '',
        city:                          answer_for('city'),
        state:                         answer_for('state'),
        zip:                           answer_for('postal_code'),
        country:                       answer_for('country'),
        phone1:                        answer_for('phone_number'),
        phone2:                        '',
        fax:                           '',
        email:                         answer_for('email'),
        journal:                       @paper.journal.name,
        pubdnumber:                    'placeholderPubDNumber',
        doi:                           @paper.doi,
        dtitle:                        @paper.title,
        issn:                          '',
        price:                         '',
        waiver_text:                   '', # highlighted in Linda's spreadsheet. not sure why
        discount_institution:          '', # highlighted
        collection:                    '', # highlighted
        direct_bill:                   '', # highlighted
        import_date:                   '',
        line_no:                       '',
        original_submission_start_date:'',
        actual_online_pub_date:        '',
        batch_no:                      '',
        exception:                     '',
        direct_bill_expense:           '', # highlighted
        date_first_entered_production: '', # highlighted
        pub_charge_response:           '', # highlighted
        pub_waiver_response:           '', # highlighted
        institutional_response:        '', # highlighted
        gpi_response:                  '', # highlighted
        gpi_tier:                      '',
        base_price:                    '',
        discount_price:                '',
        discount_percent:              '',
        waiver_amount:                 '',
        collections_response:          '', # highlighted
        eligible:                      '',
        rescind:                       '',
        standard_collection_id:        '',
        terms1:                        '',
        terms2:                        '',
        terms3:                        '',
        terms4:                        '',
        terms5:                        '',
        final_dispo_accept:            'placeholderFinalDispoAccept',
        terms6:                        '',
        category:                      'placeholderCategory',
        split:                         ''
      }
    end

    def to_csv

      data = paper_to_billing_log_hash

      csv = CSV.new ""
      csv << data.keys
      csv << data.values
      csv
    end

    def to_s3
      s3       = CloudServices::S3Service.new.connection

      directory = s3.directories.new(
        key:    Rails.application.config.s3_bucket,
        public: false
      )

      s3_file = directory.files.create(
        key:    "billing/#{filename}",
        body:   to_csv.string,
        public: true
      )

      s3_file.save # returns true if !errors
    end

    def filename
      @filename ||= "billing-log-paper-#{@paper.id}-#{Time.now.utc.to_i}.csv"
    end

    private

    def answer_for(ident)
      answer = @paper.billing_card.answer_for(ident)
      answer.value if answer
    end
  end
end