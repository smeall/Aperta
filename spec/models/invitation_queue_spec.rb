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

describe InvitationQueue do
  def make_queue(invite_array)
    q = FactoryGirl.create :invitation_queue, invitations: invite_array

    invite_array.each_with_index do |i, pos|
      Invitation.where(id: i.id).update_all(position: pos + 1)
      i.reload
    end
    q
  end

  let(:paper) { FactoryGirl.create(:paper) }
  let(:task) { FactoryGirl.create(:paper_editor_task, paper: paper) }

  describe "#add_invitation" do
    let(:queue) do
      make_queue [
        ungrouped_1,
        ungrouped_2
      ]
    end
    let(:invitation) { FactoryGirl.create(:invitation, task: task, paper: paper) }
    it 'should add the invitation to the bottom of the queue' do
      queue.add_invitation(invitation)
      expect(invitation.invitation_queue).to eq(queue)
      expect(invitation.reload.position).to eq(3)
    end
  end

  let(:group_1_primary) do
    FactoryGirl.create(:invitation, task: task, paper: paper, body: 'group_1_primary')
  end

  let(:g1_alternate_1) do
    FactoryGirl.create(:invitation, primary: group_1_primary, task: task, paper: paper, body: 'g1_alternate_1')
  end

  let(:g1_alternate_2) do
    FactoryGirl.create(:invitation, primary: group_1_primary, task: task, paper: paper, body: 'g1_alternate_2')
  end

  let(:g1_alternate_3) do
    FactoryGirl.create(:invitation, primary: group_1_primary, task: task, paper: paper, body: 'g1_alternate_3')
  end

  let(:group_2_primary) do
    FactoryGirl.create(:invitation, task: task, paper: paper, body: 'group_2_primary')
  end

  let(:g2_alternate_1_sent) do
    FactoryGirl.create(:invitation, :invited, primary: group_2_primary, task: task, paper: paper, body: 'g2_alternate_1_sent')
  end

  let(:g2_alternate_2) do
    FactoryGirl.create(:invitation, primary: group_2_primary, task: task, paper: paper, body: 'g2_alternate_2')
  end

  let(:sent_1) { FactoryGirl.create(:invitation, :invited, task: task, paper: paper, body: 'sent_1') }
  let(:sent_2) { FactoryGirl.create(:invitation, :invited, task: task, paper: paper, body: 'sent_2') }

  let(:ungrouped_1) { FactoryGirl.create(:invitation, task: task, paper: paper, body: 'ungrouped_1') }
  let(:ungrouped_2) { FactoryGirl.create(:invitation, task: task, paper: paper, body: 'ungrouped_2') }
  let(:ungrouped_3) { FactoryGirl.create(:invitation, task: task, paper: paper, body: 'ungrouped_3') }

  describe "#valid_new_positions_for_invitation" do
    let(:full_queue) do
      make_queue [
        group_1_primary, # 1
        g1_alternate_1, # 2
        g1_alternate_2, # 3
        g1_alternate_3, # 4
        group_2_primary, # 5
        g2_alternate_1_sent, # 6
        g2_alternate_2, # 7
        sent_1, # 8
        sent_2, # 9
        ungrouped_1, # 10
        ungrouped_2, # 11
        ungrouped_3  # 12
      ]
    end

    it "an ungrouped primary can go to the position of other ungrouped primaries" do
      expect(full_queue.valid_new_positions_for_invitation(ungrouped_1)).to contain_exactly(12, 11)
      expect(full_queue.valid_new_positions_for_invitation(ungrouped_2)).to contain_exactly(12, 10)
    end

    it "an alternate can go to the position of another unsent alternate in its group" do
      expect(full_queue.valid_new_positions_for_invitation(g1_alternate_1)).to contain_exactly(4, 3)
      expect(full_queue.valid_new_positions_for_invitation(g1_alternate_2)).to contain_exactly(4, 2)
      expect(full_queue.valid_new_positions_for_invitation(g2_alternate_2)).to eq([])
    end

    it "a grouped primary has no valid positions" do
      expect(full_queue.valid_new_positions_for_invitation(group_1_primary)).to eq([])
    end

    it "sent (invited) invites have no valid positions" do
      expect(full_queue.valid_new_positions_for_invitation(sent_1)).to eq([])
    end
  end

  let(:small_queue) do
    make_queue [
      group_1_primary, # 1
      g1_alternate_1, # 2
      sent_1, # 3
      ungrouped_1, # 4
      ungrouped_2, # 5
      ungrouped_3  # 6
    ]
  end

  describe "#move_invitation_to_position" do
    it "can move stuff to the end of the list" do
      small_queue.move_invitation_to_position(ungrouped_1, 5)
      expect(ungrouped_1.reload.position).to eq(5)
      expect(ungrouped_2.reload.position).to eq(4)
    end
  end

  describe "#assign_primary" do
    context "error cases" do
      it "blows up if the invitation and the primary don't belong to the same queue" do
        some_other_primary = FactoryGirl.create :invitation,
          task: task,
          paper: paper,
          invitation_queue: nil
        expect { small_queue.assign_primary(invitation: g1_alternate_1, primary: some_other_primary) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invitation is a primary with alternates." do
        expect { small_queue.assign_primary(invitation: group_1_primary, primary: ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invitation is not in a pending state" do
        group_1_primary.update(state: "invitationd")
        expect { small_queue.assign_primary(invitation: group_1_primary, primary: ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the primary is an alternate" do
        expect { small_queue.assign_primary(invitation: ungrouped_1, primary: g1_alternate_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "the invitation and the primary are both ungrouped" do
      it "places the primary and the new alternate at the bottom of the other grouped primaries" do
        small_queue.assign_primary(invitation: ungrouped_2, primary: ungrouped_1)
        expect(ungrouped_1.reload.position).to eq(3)
        expect(ungrouped_2.reload.position).to eq(4)
      end
    end

    context "the invitation and the primary are already grouped" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          g1_alternate_2, # 3
          group_2_primary, # 4
          g2_alternate_2, # 5
        ]
      end
      context "assigning the invitation to another primary" do
        it "assigns and reorders successfully" do
          small_queue.assign_primary(invitation: g1_alternate_2, primary: group_2_primary)
          expect(g1_alternate_2.reload.position).to eq(5)
          expect(g1_alternate_2.primary_id).to eq(group_2_primary.id)
        end
      end
    end

    context "the invitation is ungrouped, the primary already has alternates" do
      it "places the new alternate below the existing alternates" do
        small_queue.assign_primary(invitation: ungrouped_1, primary: group_1_primary)
        expect(ungrouped_1.reload.position).to eq(3)
        expect(group_1_primary.reload.position).to eq(1)
      end
    end
  end

  describe "#unassign_primary_from" do
    context "error cases" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          ungrouped_1, # 4
        ]
      end
      it "blows up if the invitation is a primary with alternates." do
        expect { small_queue.unassign_primary_from(group_1_primary) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invitation has no primary" do
        expect { small_queue.unassign_primary_from(ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invitation is not in a pending state" do
        g1_alternate_1.update(state: "invited")
        expect { small_queue.unassign_primary_from(g1_alternate_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "the primary has other alternates" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          g1_alternate_2, # 3
          ungrouped_1, # 4
        ]
      end

      it "The alternate should no longer be linked as an alternate" do
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(g1_alternate_1.reload.primary).to be_blank
      end

      it "moves the ungrouped invitation to the bottom of the list" do
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(group_1_primary.reload.position).to eq(1) # the primary should stay put
        expect(g1_alternate_1.reload.position).to eq(4)
      end
    end

    context "the primary has no other alternates" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          ungrouped_1, # 3
        ]
      end

      it "The alternate should no longer be linked as an alternate" do
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(g1_alternate_1.reload.primary).to be_blank
      end

      it <<-DESC.strip_heredoc do
        moves the newly-ungrouped primary and the ungrouped invitation to the bottom of the list.
        The ungrouped primary is now just another regular invitation
      DESC
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(group_1_primary.reload.position).to eq(2)
        expect(g1_alternate_1.reload.position).to eq(3)
      end
    end
  end

  describe "#destroy_invitation" do
    context "the invitation is an ungrouped primary" do
      let(:small_queue) do
        make_queue [
          ungrouped_1, # 1
          ungrouped_2, # 2
        ]
      end

      it "removes the invitation from the list and repositions the other invitations" do
        small_queue.destroy_invitation(ungrouped_1)
        expect(small_queue.invitations.pluck(:id)).to_not include(ungrouped_1.id)
        expect(ungrouped_2.reload.position).to eq(1)
      end
    end

    context "the invitation is an alternate" do
      context "the primary has other alternates" do
        let(:small_queue) do
          make_queue [
            group_1_primary, # 1
            g1_alternate_1, # 2
            g1_alternate_2, # 3
            ungrouped_1, # 4
          ]
        end

        it "removes the invitation from the queue, destroys it, and reorders the list" do
          small_queue.destroy_invitation(g1_alternate_1)
          expect(small_queue.invitations.pluck(:id)).to_not include(g1_alternate_1.id)
          expect(g1_alternate_1).to be_destroyed
          expect(group_1_primary.reload.position).to eq(1) # the primary should stay put
          expect(ungrouped_1.reload.position).to eq(3)
        end
      end

      context "the primary has no other alternates" do
        let(:small_queue) do
          make_queue [
            group_1_primary, # 1
            g1_alternate_1, # 2
            ungrouped_1, # 3
          ]
        end

        it "removes the invitation from the queue's invitations and moves the newly-ungrouped primary to the bottom of the list" do
          small_queue.destroy_invitation(g1_alternate_1)
          expect(small_queue.invitations.pluck(:id)).to_not include(g1_alternate_1.id)
          expect(group_1_primary.reload.position).to eq(2)
        end
      end
    end

    context "the invitation is a primary with alternates" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
        ]
      end

      it "blows up. invitations must be first ungrouped before they can be removed from the queue" do
        expect { small_queue.destroy_invitation(group_1_primary) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#send_invitation" do
    context "the invitation is an ungrouped primary" do
      context "there are existing sent invitations" do
        let(:queue) do
          make_queue [
            group_2_primary, # 1
            g2_alternate_2, # 2
            sent_1, # 3
            ungrouped_1, # 4
            ungrouped_2, # 5
          ]
        end

        it "gets repositioned to the bottom of the sent invitations" do
          queue.send_invitation(ungrouped_2)
          expect(ungrouped_2.reload.position).to eq(4)
        end

        it "calls 'invite!'" do
          expect(ungrouped_2).to receive(:invite!)
          queue.send_invitation(ungrouped_2)
        end

        # note that this condition is impossible to reasonably simulate except by
        # making the test data bad before performing the operation.  In reality this
        # method and all of the other ones that modify invitation positions will fail
        # if there are duplicate positions at the end of the operation
        it "will blow up if any invitations happen to have duplicate positions" do
          queue.invitations.find_by(position: 4).update_column(:position, 5)
          expect { queue.send_invitation(g2_alternate_2) }
            .to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context "there are groups but no sent invitations" do
        let(:queue) do
          make_queue [
            group_2_primary, # 1
            g2_alternate_2, # 2
            ungrouped_1, # 3
            ungrouped_2, # 4
          ]
        end

        it "gets repositioned after the end of the groups" do
          queue.send_invitation(ungrouped_2)
          expect(ungrouped_2.reload.position).to eq(3)
        end
      end
    end

    context "the invitation is a primary with alternates" do
      let(:queue) do
        make_queue [
          group_2_primary, # 1
          g2_alternate_1_sent, # 2
          g2_alternate_2, # 3
        ]
      end
      it "does not get repositioned" do
        queue.send_invitation(group_2_primary)
        expect(group_2_primary.reload.position).to eq(1)
      end

      it "calls 'invite!'" do
        expect(group_2_primary).to receive(:invite!)
        queue.send_invitation(group_2_primary)
      end
    end

    context "the invite is an alternate" do
      let(:g2_alternate_3) do
        FactoryGirl.create(:invitation, primary: group_2_primary, task: task, paper: paper, body: 'g2_alternate_3')
      end

      let(:queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          group_2_primary, # 3
          g2_alternate_1_sent, # 4
          g2_alternate_2, # 5
          g2_alternate_3 # 6
        ]
      end

      it "gets repositioned to the bottom of the sent alternates for its primary" do
        queue.send_invitation(g2_alternate_3)
        expect(g2_alternate_3.reload.position).to eq(5)

        queue.send_invitation(g1_alternate_1.reload) # reload since acts_as_list has changed its position
        expect(g1_alternate_1.reload.position).to eq(2)
      end

      it "calls 'invite!'" do
        expect(g2_alternate_3).to receive(:invite!)
        queue.send_invitation(g2_alternate_3)
      end
    end
  end
end
