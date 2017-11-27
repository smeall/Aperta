# rubocop:disable Metrics/BlockLength
namespace :data do
  namespace :migrate do
    desc <<-DESC
      APERTA-11875: Add ident to preprint posting card
    DESC

    task aperta_11875_add_ident_to_preprint_posting_card: :environment do
      CardContent.transaction do
        card = Card.find_by(name: "Preprint Posting")
        raise Exception, "No card with name 'Preprint Posting'" unless card

        radio = card.card_version(:latest).card_contents.find_by(content_type: "radio")
        raise Exception, "Card didn't have the radio button question." unless radio

        result = radio.update(ident: "preprint-posting--consent")
        raise Exception, "Failed to update Card Content #{radio.id}." unless result

        p "Card updated with ident 'preprint-posting--consent'."
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength