/**
 * Copyright (c) 2018 Public Library of Science
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
*/

import hbs from 'htmlbars-inline-precompile';
import page from 'tahi/tests/pages/invitation-manager';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import { manualSetup, make } from 'ember-data-factory-guy';
import { moduleForComponent, test } from 'ember-qunit';
import FakeCanService from 'tahi/tests/helpers/fake-can-service';

moduleForComponent('invitation-manager', 'Integration | Component | invitation manager', {
  integration: true,
  beforeEach() {
    registerCustomAssertions();
    manualSetup(this.container);
    page.setContext(this);
    this.task = make('paper-reviewer-task', 'withInvitations');
    var can = FakeCanService.create();
    this.registry.register('service:can', can.allowPermission('manage_invitations', this.task).asService());
    this.render(hbs`{{invitation-manager task=task}}`);
  },
  afterEach() {
    page.removeContext();
  }
});

test('it renders invitations', function(assert) {
  assert.expect(2);
  const invitationCount = this.task.get('invitations.length');
  assert.ok(invitationCount > 0, 'there should be some invitations on the task');
  assert.equal(page.invitations().count, invitationCount, 'theres should be some rendered invitations');
});

test('clicking an invitation expands that invitation', function(assert) {
  assert.expect(3);
  const firstInvitation = page.invitations(0);
  assert.notOk(firstInvitation.isExpanded, 'the invitation should not be expanded');
  firstInvitation.toggleExpand();
  assert.ok(firstInvitation.isExpanded, 'the invitation should be expanded');
  firstInvitation.toggleExpand();
  assert.notOk(firstInvitation.isExpanded, 'the invitation should not be expanded');
});

test('No invitation are draggable when one is expanded', function(assert) {
  assert.expect(3);
  const firstInvitation = page.invitations(0);
  assert.ok(page.allInvitationsDraggable(), 'all invitations should be draggable');
  firstInvitation.toggleExpand();
  assert.ok(page.noInvitationsDraggable(), 'no invitations should be draggable');
  firstInvitation.toggleExpand();
  assert.ok(page.allInvitationsDraggable(), 'all invitations should be draggable');
});
