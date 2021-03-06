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

require 'support/pages/page_fragment'

class PageNotReady < Capybara::ElementNotFound; end

class DeclarationFragment < PageFragment
  def answer
    find('textarea').value
  end

  def answer= value
    id = find('textarea')[:id]
    fill_in id, with: value
    find('label').click # blur the textarea
  end
end

class PaperPage < Page
  include ActionView::Helpers::JavaScriptHelper

  path :root
  text_assertions :paper_title, '#control-bar-paper-title'
  text_assertions :journal, '.paper-journal'

  def initialize element = nil
    find '.manuscript'
    super
  end

  def view_task(task, overlay_class=nil)
    name = ''
    element = nil

    if task.class == String
      element = find('.task-disclosure', text: task)
    else
      name = task.type.gsub(/.+::/,'').underscore.dasherize
      element = find(".#{name}")
    end

    fragment_class = overlay_class ? overlay_class : PaperTaskOverlay

    fragment = fragment_class.new(element)

    fragment.open_task
    fragment
  end

  def visit_dashboard
    require 'support/pages/dashboard_page'
    click_link 'Dashboard'
    DashboardPage.new
  end

  def show_contributors
    require 'support/pages/overlays/add_collaborators_overlay'
    reload
    contributors_link.click
    click_contributors_link
    AddCollaboratorsOverlay.new(find('.show-collaborators-overlay'))
  end

  def click_contributors_link
    add_contributors_link.click
  end

  def contributors_link
    find '#nav-collaborators'
  end

  def downloads_link
    find '#nav-downloads'
  end

  def add_contributors_link
    find '#nav-add-collaborators'
  end

  def recent_activity_button
    first(:css, '#nav-recent-activity')
  end

  def version_button
    first(:css, '#nav-versions')
  end

  def visit_task_manager
    click_link 'Workflow'
    TaskManagerPage.new
  end

  def title=(string)
    element = title
    element.send_keys = string
  end

  def abstract=(_val)
    # find('#paper-title').set(val)
    raise NotImplementedError, "TODO: The UI on paper#edit needs to be implemented"
  end

  def body
    find('#paper-body')
  end

  def versioned_body
    find('#paper-body')
  end

  def view_versions
    version_button.click
  end

  def select_viewing_version(version)
    power_select('.paper-viewing-version', target_string(version))
  end

  def select_comparison_version(version)
    power_select('.paper-comparison-version', target_string(version))
  end

  def has_body_text?(text)
    find('#paper-body').has_text?(text)
  end

  def loading_paper?
    has_css?('.progress-spinner-message')
  end

  # Use this method instead of negating `loading_paper?`
  # expect(page).to_not be_loading_paper will only return `false` after
  # the default capyabara wait expires, adding an extra 4 seconds to a passing test
  def not_loading_paper?
    has_no_css?('.progress-spinner-message')
  end

  def journal
    find(:css, '.paper-journal')
  end

  def title
    find('#paper-title')
  end

  def paper_type
    find('#paper_paper_type').find("option[value='#{select.value}']")
  end

  def paper_type=(value)
    find('#paper_paper_type').select value
  end

  def save
    code = <<HERE
var editorController = Tahi.__container__.lookup("controller:paper/index/html-editor");
editorController.savePaper();
HERE
    page.execute_script code
  end

  def submit(&blk)
    require 'support/pages/overlays/submit_paper_overlay'
    click_on "Submit"
    SubmitPaperOverlay.new.tap do |overlay|
      if blk
        blk.call overlay
      end
    end
  end

  def withdraw_paper
    find('.more-dropdown-menu').click
    find('.withdraw-link').click

    expect(page).to have_css('.paper-withdraw-wrapper')
    within '.paper-withdraw-wrapper' do
      find('textarea.withdraw-reason').set 'I really decided not to publish'
      find('button.withdraw-yes').click
    end

    expect(page).to have_css(
      '.withdrawal-banner',
      text: /This paper has been withdrawn from.*and is in View Only mode/
    )
  end

  def css
    find('.manuscript')['style']
  end

  private

  def abstract_node
    find(:css, '#paper-abstract')
  end

  def target_string(version)
    file_type_string = version.file_type ? "(#{version.file_type.upcase})" : ''
    date = version.updated_at.strftime('%b %d, %Y')
    file_type_and_date = "#{file_type_string} - #{date}".strip
    if version.major_version.blank?
      "(draft) #{file_type_and_date}"
    else
      "v#{version.major_version}.#{version.minor_version} #{file_type_and_date}"
    end
  end
end
