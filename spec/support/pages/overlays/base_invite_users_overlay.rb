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

require 'support/pages/card_overlay'
require 'support/rich_text_editor_helpers'

# PaperReviewerTask and PaperEditorTask both inherit from this overlay
class BaseInviteUsersOverlay < CardOverlay
  include RichTextEditorHelpers

  text_assertions :invitee, '.invitation-item-full-name'

  def invited_users=(users)
    users.each do |invitee|
      # Find thru auto-suggest
      fill_in "invitation-recipient", with: invitee.email
      find(".auto-suggest-item", text: "#{invitee.full_name} <#{invitee.email}>").click

      # Invite
      find('.invitation-email-entry-button').click
      row = find('.active-invitations .invitation-item-header', text: invitee.full_name)
      row.find('.invite-send').click

      # Make sure we see they were invited
      expect(page).to have_css('.active-invitations')
      expect(page).to have_css('.active-invitations .invitation-item-full-name', text: invitee.full_name)
    end
  end

  def invite_new_user(email)
    fill_in "invitation-recipient", with: email
    find('.invitation-email-entry-button').click
    row = find('.active-invitations .invitation-item-header', text: email)
    row.find('.invite-send').click
  end

  def add_to_queue(invitee)
    fill_in "invitation-recipient", with: invitee.email
    find(".auto-suggest-item", text: "#{invitee.full_name} <#{invitee.email}>").click

    # add to queue button
    find('.invitation-email-entry-button').click
  end

  def edit_invitation(invitee)
    find('.invitation-item-header', text: invitee.first_name).click
    find('.invitation-item-action-edit').click
  end

  def select_first_alternate
    # Using the capybara-select2 helper here doesn't work because... not sure.
    # I think we are using select2 strangely here.
    within(".invitation-item--edit") do
      find('.link-alternate-select.select2-container').click
    end

    find(".select2-highlighted").click
  end

  def invitation_body=(content)
    set_rich_text editor: 'invitation-edit-body', text: content
  end

  def has_invitees?(*invitee_names)
    invitee_names.all? do |name|
      page.has_css?('.invitation-item-full-name', text: name)
    end
  end

  def total_invitations_count(count)
    page.has_css? '.invitation-item', count: count
  end

  def active_invitations_count(count)
    page.has_css? '.active-invitations .invitation-item', count: count
  end

  def expired_invitations_count(count)
    page.has_css? '.expired-invitations .invitation-item', count: count
  end
end
