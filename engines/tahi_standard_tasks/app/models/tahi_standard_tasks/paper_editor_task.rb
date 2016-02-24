module TahiStandardTasks
  class PaperEditorTask < Task
    include ClientRouteHelper
    include Rails.application.routes.url_helpers
    DEFAULT_TITLE = 'Invite Academic Editor'
    DEFAULT_ROLE = 'admin'

    include Invitable

    def invitation_invited(invitation)
      if paper.authors_list.present?
        invitation.update! information: "Here are the authors on the paper:\n\n#{paper.authors_list}"
      end
      PaperEditorMailer.delay.notify_invited({
        invitation_id: invitation.id
      })
    end

    def invitation_accepted(invitation)
      replace_editor invitation
      PaperAdminMailer.delay.notify_admin_of_editor_invite_accepted(
        paper_id:  invitation.paper.id,
        editor_id: invitation.invitee.id
      )
    end

    def invitee_role
      Role::ACADEMIC_EDITOR_ROLE
    end

    # This method is a bunch of english text. It should be moved to
    # its own file, but we're not sure where. It's here, instead of a
    # mailer template, because users can edit the text before it gets
    # sent out.
    # rubocop:disable Metrics/LineLength, Metrics/MethodLength
    def invite_letter
      template = <<-TEXT.strip_heredoc
Dear Dr. [EDITOR NAME],

I am writing to seek your advice as the academic editor on a manuscript entitled '%{manuscript_title}'. The corresponding author is %{author_name}, and the manuscript is under consideration at %{journal_name}.

We would be very grateful if you could let us know whether or not you are able to take on this assignment within 24 hours, so that we know whether to await your comments, or if we need to approach someone else. To accept or decline the assignment via our submission system, please use the link below. If you are available to help and have no conflicts of interest, you also can view the entire manuscript via this link.

<a href="%{dashboard_url}">Dashboard</a>

If you do take this assignment, and think that this work is not suitable for further consideration by PLOS Biology, please tell us if it would be more appropriate for one of the other PLOS journals, and in particular, PLOS ONE (<a href="http://plos.io/1hPjumI">http://plos.io/1hPjumI</a>). If you suggest PLOS ONE, please let us know if you would be willing to act as Academic Editor there. For more details on what this role would entail, please go to <a href="http://journals.plos.org/plosone/s/journal-information ">http://journals.plos.org/plosone/s/journal-information</a>.

I have appended further information, including a copy of the abstract and full list of authors below.

My colleagues and I are grateful for your support and advice. Please don't hesitate to contact me should you have any questions.

Kind regards,
[YOUR NAME]
%{journal_name}

***************** CONFIDENTIAL *****************

Manuscript Title:
%{manuscript_title}

Authors:
%{authors}

Abstract:
%{abstract}

To view this manuscript, please use the URL presented above in the body of the e-mail.

Clicking the button to accept this assignment will allow you to access the full submission from the Dashboard link in your main menu. Clicking on the title will take you to the Manuscript page, where you can view and/or download the manuscript along with associated figures and any SI files. You can view this information from your Dashboard at any time by logging into your account. You will be asked to provide your thoughts and comments in a discussion forum on the Manuscript page.

      TEXT
      template % template_data
    end
    # rubocop:enable Metrics/LineLength, Metrics/MethodLength

    private

    def template_data
      {
        manuscript_title: paper.display_title(sanitized: false),
        journal_name: paper.journal.name,
        author_name: paper.creator.full_name,
        authors: paper.authors_list,
        abstract: paper.abstract,
        dashboard_url: client_dashboard_url
      }
    end

    def replace_editor(invitation)
      user = User.find(invitation.invitee_id)
      role = paper.journal.academic_editor_role

      # Remove any old editors
      paper.assignments.where(role: role).destroy_all
      paper.assignments.where(user: user, role: role).first_or_create!
    end
  end
end
