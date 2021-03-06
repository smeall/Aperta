# Copyright (c) 2018 Public Library of Science

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

require 'rails_helper'

describe CardFactory do
  describe "creating cards from configurations" do
    context "there is no card in the db for a given configuration and journal" do
      let(:journal) { FactoryGirl.create(:journal) }
      it "creates a new card that is published if a journal is provided" do
        new_card = CardFactory.new(journal: journal)
                     .create_from_content(name: "Foo", new_content: [])
        expect(new_card).to be_published
      end

      it "creates new nested content properly" do
        new_card = CardFactory.new(journal: journal)
          .create_from_content(
            name: "New Card",
            new_content: [
              {
                ident: "foo",
                content_type: "text",
                text: "new foo text",
                children: [
                  {
                    ident: "bar",
                    content_type: "text",
                    text: "child bar text"
                  }
                ]
              }
            ]
          )

        version = new_card.latest_card_version
        expect(version.card_contents.find_by(ident: "foo").text).to eq("new foo text")
        expect(version.card_contents.find_by(ident: "bar").text).to eq("child bar text")
        expect(version.card_contents.count).to eq(3)
      end

      it "creates a new card that is locked if no journal is provided" do
        new_card = CardFactory.new(journal: nil)
                     .create_from_content(name: "Foo", new_content: [])
        expect(new_card).to be_locked
      end
    end

    context "a card for the given configuration/journal exists" do
      describe "updating card content" do
        let(:journal) { FactoryGirl.create(:journal) }
        let!(:card) do
          c = FactoryGirl.create(:card, :versioned, name: "TestCard", journal: journal, state: "draft")
          # Unset the ident for the root element to avoid problems with updating the content
          c.content_root_for_version(:latest).update(ident: nil)
          c
        end

        before do
          version = card.latest_card_version
          version.content_root.children << FactoryGirl.create(
            :card_content,
            card_version: version,
            parent: version.content_root,
            ident: "foo",
            content_type: "text",
            value_type: nil,
            text: "original text"
          )
        end

        let(:version) { card.latest_card_version }

        it "uses idents to match existing card content" do
          CardFactory.new(journal: journal)
            .create_from_content(
              name: card.name,
              new_content: [
                {
                  ident: "foo",
                  content_type: "text",
                  text: "new foo text"
                }
              ]
            )

          expect(version.card_contents.find_by(ident: "foo").text).to eq("new foo text")
          expect(version.card_contents.count).to eq(2)
        end

        it "creates nested children of existing content properly" do
          CardFactory.new(journal: journal)
            .create_from_content(
              name: card.name,
              new_content: [
                {
                  ident: "foo",
                  content_type: "text",
                  text: "new foo text",
                  children: [
                    {
                      ident: "bar",
                      content_type: "text",
                      text: "child bar text"
                    }
                  ]
                }
              ]
            )

          expect(version.card_contents.find_by(ident: "foo").text).to eq("new foo text")
          expect(version.card_contents.find_by(ident: "bar").text).to eq("child bar text")
          expect(version.card_contents.count).to eq(3)
        end

        it "creates new card content if the ident in the config is blank or different" do
          CardFactory.new(journal: journal)
            .create_from_content(
              name: card.name,
              new_content: [
                {
                  ident: "foo",
                  content_type: "text",
                  text: "new foo text"
                },
                {
                  ident: "bar",
                  content_type: "text",
                  text: "bar text"
                }
              ]
            )
          expect(version.card_contents.find_by(ident: "foo").text).to eq("new foo text")
          expect(version.card_contents.find_by(ident: "bar").text).to eq("bar text")
          expect(version.card_contents.count).to eq(3)
        end

        it "blows up if an existing ident is not passed in as part of the new content" do
          expect do
            CardFactory.new(journal: journal)
            .create_from_content(
              name: card.name,
              new_content: [
                {
                  ident: "bar",
                  content_type: "text",
                  text: "bar text"
                }
              ]
            )
          end.to raise_error RuntimeError
        end

        it "blows up if the existing card's latest version is > 1" do
          card.update!(latest_version: 2)
          expect do
            CardFactory.new(journal: journal)
              .create_from_content(
                name: card.name,
                new_content: [
                  {
                    ident: "bar",
                    content_type: "text",
                    text: "bar text"
                  }
                ]
              )
          end.to raise_error ArgumentError
        end

        it "ignores existing card content that does not have an ident" do
          CardContent.find_by(ident: "foo").update!(ident: nil, text: "keep me")

          CardFactory.new(journal: journal)
            .create_from_content(
              name: card.name,
              new_content: [
                {
                  ident: "foo",
                  content_type: "text",
                  text: "new foo text"
                }
              ]
            )

          expect(version.card_contents.find_by(ident: "foo").text).to eq("new foo text")
          expect(version.card_contents.count).to eq(3)
        end
      end

      describe "updating an existing card's state" do
        let!(:card) do
          c = FactoryGirl.create(:card, :versioned, :draft, name: "TestCard", journal: journal)
          # Unset the ident for the root element to avoid problems with updating the content
          c.content_root_for_version(:latest).update(ident: nil)
          c
        end

        let(:journal) { FactoryGirl.create(:journal) }

        subject(:update_card) do
          CardFactory.new(journal: journal)
            .create_from_content(name: card.name, new_content: [])
        end

        it "does not create a new card" do
          expect do
            update_card
          end.to_not change(Card, :count)
        end

        context "with a journal" do
          it "publishes the card with a message if it's not published" do
            expect(card).to be_draft
            updated = update_card
            expect(updated).to be_published
            expect(updated.latest_card_version.history_entry).to \
              eq("Loaded from a configuration file")
          end
        end

        context "no journal provided" do
          let(:journal) { nil }
          it "locks the card if it's not locked" do
            expect(update_card).to be_locked
          end

          it "does nothing if the card is already locked" do
            card.update!(state: "locked")
            update_card
            expect(card.reload).to be_locked
          end
        end
      end
    end
  end
end
