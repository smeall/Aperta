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

describe XmlCardLoader do
  let(:content1) { '<Description ident="foo"><text>foo</text></Description>' }
  let(:content2) { '<Description ident="bar"><text>bar</text></Description>' }

  let!(:card) { FactoryGirl.create(:card, :versioned, name: "original name") }
  let(:xml_card_loader) { XmlCardLoader.new(card) }

  describe 'XML format check' do
    before(:each) do
      JournalFactory.seed_letter_templates(card.journal)
    end

    xml_dir = Rails.root.join('lib', 'custom_card', 'configurations', 'xml_content')
    Dir.glob("#{xml_dir}/*.xml").each do |xml_file|
      it "should round-trip #{xml_file}" do
        xml = File.read(xml_file)
        card = xml_card_loader.load(xml)
        card.save
        expect(card.reload.to_xml).to be_equivalent_to(xml)
      end
    end
  end

  describe 'error handling' do
    context 'xml does not adhere to xml schema' do
      let(:xml) { '<foo/>' }

      it 'throws an exception' do
        expect { xml_card_loader.load(xml) }.to raise_exception(XmlCardDocument::XmlValidationError) { |ex| ex.errors.first[":message"] == 'element "foo" not allowed anywhere; expected element "card"' }
      end
    end

    context 'xml has two content roots' do
      let(:xml) { "<card required-for-submission='false' workflow-display-only='true'>#{content1}#{content2}</card>" }

      it 'throws an exception' do
        expect { xml_card_loader.load(xml) }.to raise_exception(XmlCardDocument::XmlValidationError) { |ex| ex.errors.first[":message"] == 'element "content" not allowed here; expected the element end-tag' }
      end
    end

    context 'when saving versions and CardContent model is invalid' do
      let(:xml) do
        <<-XML
        <card required-for-submission='false' workflow-display-only='true'>
          <DisplayChildren>
            <ShortInput ident='foo' value-type='html'>
            </ShortInput>
          </DisplayChildren>
        </card>
      XML
      end

      it 'delegates errors to XmlCardDocument::XmlValidationError' do
        expect { xml_card_loader.load(xml) }.to raise_exception(XmlCardDocument::XmlValidationError)
      end
    end
  end

  describe '.new_version_from_xml_string' do
    let(:xml) { '<card/>' }

    it 'creates a new card_version on the card' do
      expect_any_instance_of(XmlCardLoader).to receive(:load).with(xml, replace_latest_version: false)
      XmlCardLoader.new_version_from_xml_string('<card/>', card)
    end
  end

  describe '.replace_draft_from_xml_string' do
    let(:xml) { '<card/>' }

    it 'creates a new card_version on the card' do
      expect_any_instance_of(XmlCardLoader).to receive(:load).with(xml, replace_latest_version: true)
      XmlCardLoader.replace_draft_from_xml_string('<card/>', card)
    end
  end

  describe 'creating or replacing a card_version using :replace_latest_version flag' do
    let(:xml) { "<card required-for-submission='false' workflow-display-only='true'>#{content1}</card>" }

    it 'when true, it replaces current card_version' do
      expect {
        xml_card_loader.load(xml, replace_latest_version: true)
      }.to_not change {
        card.reload.card_versions.count
      }.from(1)
    end

    it 'when false, it adds a new card_version' do
      expect {
        xml_card_loader.load(xml, replace_latest_version: false)
      }.to change {
        card.reload.card_versions.count
      }.from(1).to(2)
    end
  end

  describe 'setting card_version attributes' do
    let(:xml) { "<card required-for-submission='false' workflow-display-only='true'>#{content1}</card>" }

    before do
      card.latest_card_version.update(required_for_submission: true, workflow_display_only: false)
    end

    it 'sets #required_for_submission' do
      expect {
        card = xml_card_loader.load(xml)
        card.save
      }.to change {
        card.reload.latest_card_version.required_for_submission
      }.from(true).to(false)
    end

    it 'increments #version' do
      expect {
        card = xml_card_loader.load(xml)
        card.save
      }.to change {
        card.reload.latest_card_version.version
      }.from(1).to(2)
    end

    it 'sets #workflow_display_only' do
      expect {
        card = xml_card_loader.load(xml)
        card.save
      }.to change {
        card.reload.latest_card_version.workflow_display_only
      }.from(false).to(true)
    end
  end

  describe 'setting card_content with validations' do
    let(:root_content) { card.reload.latest_card_version.card_contents.root }
    let(:child_content) { root_content.children.first }
    let(:validations) { child_content.card_content_validations }
    let(:xml) do
      <<-XML
        <card required-for-submission="false" workflow-display-only="true">
          <DisplayChildren>
            <ShortInput ident="foo" value-type="text" required-field="false">
              <text>foo</text>
              <validation validation-type="string-match">
                <error-message>First Validation</error-message>
                <validator>/test-one/</validator>
              </validation>
              <validation validation-type="string-match">
                <error-message>Second Validation</error-message>
                <validator>/second-one/</validator>
              </validation>
            </ShortInput>
          </DisplayChildren>
        </card>
      XML
    end

    it 'creates string match card content validations' do
      card = xml_card_loader.load(xml)
      card.save
      expect(validations.count).to eq(2)

      expect(validations.first.validation_type).to eq 'string-match'
      expect(validations.first.error_message).to eq 'First Validation'
      expect(validations.first.validator).to eq '/test-one/'

      expect(validations.second.validation_type).to eq 'string-match'
      expect(validations.second.error_message).to eq 'Second Validation'
      expect(validations.second.validator).to eq '/second-one/'
    end
  end

  describe 'setting card_content attributes' do
    let(:xml) { "<card required-for-submission='false' workflow-display-only='true'>#{content1}</card>" }
    let(:root_content) { card.reload.latest_card_version.card_contents.root }

    context 'with nested contents' do
      let(:xml) do
        <<-XML
          <card required-for-submission='false' workflow-display-only='true'>
            <DisplayChildren>
              #{content1}
              #{content2}
            </DisplayChildren>
          </card>
        XML
      end
      let(:first) { root_content.children[0] }
      let(:second) { root_content.children[1] }

      it 'creates the children' do
        card = xml_card_loader.load(xml)
        card.save
        expect(first.ident).to eq('foo')
        expect(first.content_type).to eq('description')
        expect(second.ident).to eq('bar')
        expect(second.content_type).to eq('description')
      end
    end

    describe 'setting specific card_content types' do
      context 'tech-check' do
        let(:root_content) { card.reload.latest_card_version.card_contents.root }
        let(:child_content) { root_content.children.first }
        let(:card) { FactoryGirl.create(:card, :versioned, name: 'original name') }
        let(:content1) do
          <<-XML
          <DisplayChildren>
            <TechCheck ident="doesntmatter" value-type="boolean">
              <text>You shall not PASS!</text>
              <SendbackReason value-type="boolean">
                <CheckBox ident="first-tech-check-box" value-type="boolean">
                  <default-answer-value>false</default-answer-value>
                  <text>Because REASONS!</text>
                </CheckBox>
                <CheckBox ident="second-tech-check-box" value-type="boolean">
                  <default-answer-value>false</default-answer-value>
                  <text>Because more REASONS!</text>
                </CheckBox>
                <ParagraphInput ident="potatoe" value-type="text">
                  <default-answer-value>I really mean it!  You shall not PASS!</default-answer-value>
                </ParagraphInput>
              </SendbackReason>
            </TechCheck>
          </DisplayChildren>
          XML
        end

        it 'card content was successfully created' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content).to be_present
          expect(root_content.children).to be_present
        end
      end

      context 'radio' do
        let(:content1) do
          <<-XML
            <Radio ident="foo" value-type="text" required-field="false">
              <default-answer-value>1</default-answer-value>
              <text>Question!</text>
              <possible-value label="one" value="1"/>
            </Radio>
          XML
        end

        it 'parses possible values' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.possible_values).to eq([{ 'label' => 'one', 'value' => '1' }])
        end

        it 'sets the #default_answer_value' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.default_answer_value).to eq("1")
        end
      end

      context 'check-box' do
        let(:text) { Faker::Lorem.sentence }
        let(:label) { Faker::Lorem.sentence }
        let(:content1) do
          <<-XML
            <CheckBox value-type='boolean' required-field='false'>
              <text>#{text}</text>
              <label>#{label}</label>
            </CheckBox>
          XML
        end

        it 'sets the #text' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.text).to eq(text)
        end

        it 'sets the #label' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.label).to eq(label)
        end
      end

      context 'text' do
        let(:content1) { "<Description ident='foo'><text>#{text}</text></Description>" }

        shared_examples_for :the_text_attribute_is_set_properly do
          it "set the text as expected" do
            xml_card_loader.load(xml).save
            expect(root_content.text).to eq(text)
          end
        end

        context 'when the text is a simple string' do
          let(:text) { 'Foo' }
          it_behaves_like :the_text_attribute_is_set_properly
        end

        context 'when there is trailing whitespace' do
          let(:text) { "Foo  \n" }
          it_behaves_like :the_text_attribute_is_set_properly
        end

        context 'when the text is HTML' do
          let(:text) { '<b>bold</b>' }
          it_behaves_like :the_text_attribute_is_set_properly
        end

        # https://stackoverflow.com/questions/8406251/nokogiri-to-xml-without-carriage-returns/8406635#8406635
        context 'when the text is the special kind that libxml likes to indent for some reason' do
          let(:text) { '<a href="http://example.org"><b>bold <i>italic</i></b></a>' }
          it_behaves_like :the_text_attribute_is_set_properly
        end

        context 'when the text element includes CDATA' do
          let(:text) { '<![CDATA[<a>link</a>]]>' }
          it 'throws an exception' do
            expect do
              xml_card_loader.load(xml).save
            end.to raise_error(XmlCardDocument::XmlValidationError)
          end
        end
      end

      context 'short-input' do
        let(:text) { Faker::Lorem.sentence }
        let(:content1) do
          <<-XML
            <ShortInput value-type='text' required-field="false">
              <default-answer-value>foo</default-answer-value>
              <text>#{text}</text>
            </ShortInput>
          XML
        end

        it 'sets the text to the value of the element text' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.text).to eq(text)
        end

        it 'sets the default answer value if given' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.default_answer_value).to eq("foo")
        end
      end

      context 'if-then' do
        let(:text) { Faker::Lorem.sentence }
        let(:content1) do
          <<-XML
            <If condition="mswordAllowed">
              <ParagraphInput value-type="html">
                <text>This is the THEN branch of an IF condition.</text>
              </ParagraphInput>
            </If>
          XML
        end

        it 'sets the default answer value if given' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.children.size).to eq(1)
        end
      end

      context 'if-then-else' do
        let(:text) { Faker::Lorem.sentence }
        let(:content1) do
          <<-XML
            <If condition="mswordAllowed">
              <ParagraphInput value-type="html">
                <text>This is the THEN branch of an IF condition.</text>
              </ParagraphInput>
              <ShortInput value-type="text">
                <text>This is the ELSE branch of an IF condition.</text>
              </ShortInput>
            </If>
          XML
        end

        it 'sets the default answer value if given' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.children.size).to eq(2)
        end
      end

      context 'dropdown' do
        let(:content1) do
          <<-XML
            <Dropdown ident="foo" value-type="text" required-field="false">
              <text>Question!</text>
              <possible-value label="one" value="1"/>
            </Dropdown>
          XML
        end

        it 'parses possible values' do
          card = xml_card_loader.load(xml)
          card.save
          expect(root_content.possible_values).to eq([{ 'label' => 'one', 'value' => '1' }])
        end
      end
    end
  end
end
