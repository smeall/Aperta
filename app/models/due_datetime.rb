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

# DueDatetime allows us to easily add "due dates" (really datetimes)
# to any arbitrary class.  See ReviewerReport for an example,
# especially noting the following code:
#
#     has_one :due_datetime, as: :due
#
# # # This gives you convenient and conceptually simpler access to the data:
#
#     delegate :due_at, :originally_due_at, to: :due_datetime, allow_nil: true
#
# # # This gives you an interface to use from AASM:
#
#     def set_due_datetime(length_of_time: 10.days)
#       DueDatetime.set_for(self, length_of_time: length_of_time)
#     end
#
# The reason for using datetimes is that dates are necessarily bound
# to specific time zones.  A date is really a 24-hour span of time
# and that span of time changes every time you change time zone,
# so a given date refers to a different span of hours in every zone.
# Therefore it is invalid data in a globally accessible application.
# Thus, our only bug-free option is to use datetimes, though we may
# (judiciously!) summarize that as a date in cases where the space
# does not allow for inclusion of time, as long as the user has
# easy access to the full datetime.
#
# The originally_due_at property should be set once and never changed.
#
# The due date (& time), stored in due_at can be extended, in which case
# originally_due_at would differ from due_at, and then it would be
# relevant to display the original date in the UI.
#
class DueDatetime < ActiveRecord::Base
  include ViewableModel
  belongs_to :due, polymorphic: true

  has_many :scheduled_events

  def user_can_view?(check_user)
    check_user.can?(:view, due.task)
  end

  def self.set_for(object, length_of_time:)
    (object.due_datetime ||= DueDatetime.new).set(length_of_time: length_of_time)
  end

  def set(length_of_time:)
    self.due_at = length_of_time.from_now.utc.beginning_of_hour + 1.hour
    self.originally_due_at = due_at unless originally_due_at
    save
  end
end
