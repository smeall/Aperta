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

import Ember from 'ember';
import {moduleForComponent, test} from 'ember-qunit';
import FactoryGuy from 'ember-data-factory-guy';
import { manualSetup }  from 'ember-data-factory-guy';
import sinon from 'sinon';
import wait from 'ember-test-helpers/wait';
import hbs from 'htmlbars-inline-precompile';
import { pollTaskFor } from 'ember-lifeline/mixins/run';


moduleForComponent('orcid-connect',
                   'Integration | Component | orcid connect',
                   {integration: true,
                    beforeEach: function() {
                      manualSetup(this.container);
                      this.set('confirm', (message)=>{});
                    }});

var template = hbs`{{orcid-connect orcidAccount=orcidAccount confirm=confirm open=open journal=1 canRemoveOrcid=true}}`;

test("component shows connect to orcid before a user connects to orcid", function(assert){
  let orcidAccount = FactoryGuy.make('orcid-account', {
    orcidConnectEnabled: true
  });

  this.set('orcidAccount', orcidAccount);
  this.render(template);

  assert.textPresent('.orcid-not-linked > button', 'Connect or create your ORCID ID');
});

test('component disables button when popup is open, and enables button when it is closed', function(assert){
  assert.expect(4);
  const isDisabled = (selector)=>{
    return this.$(selector).first().attr('disabled') === 'disabled';
  };
  const buttonSelector = '.orcid-not-linked > .connect-orcid';
  let orcidAccount = FactoryGuy.make('orcid-account', {
    orcidConnectEnabled: true
  });

  let openObject = {closed: false};
  let open = sinon.stub().returns(openObject);
  this.set('open', open);
  this.set('openObject', openObject);

  this.set('orcidAccount', orcidAccount);
  this.render(template);

  assert.ok(
    isDisabled(buttonSelector) === false,
    'Button is not disabled before clicking'
  );

  this.$(buttonSelector).click();
  return wait().then(() => {
    assert.spyCalled(open);
    assert.ok(
      isDisabled(buttonSelector) === true,
      'Button is disabled after clicking'
    );
    // simulate closing the popup window.
    this.set('openObject.closed', true);
    pollTaskFor('orcid-connect#popup-closed');
    return wait();
  }).then(() => {
    assert.ok(
      isDisabled(buttonSelector) === false,
      'Button is not disabled after popup is closed'
    );
  });
});

test('component shows orcid id and trash can when a user is connected to orcid', function(assert){
  let orcidAccount = FactoryGuy.make('orcid-account', {
    'status': 'authenticated',
    'identifier': '0000-0000-0000-0000',
    'orcidConnectEnabled': true
  });

  this.set('orcidAccount', orcidAccount);
  this.render(template);
  assert.elementFound('.orcid-linked');
  assert.elementFound('.remove-orcid');
});

test("component shows orcid id and trash can, and reauthorize option if accessTokenExpired", function(assert){
  let orcidAccount = FactoryGuy.make('orcid-account', {
    'status': 'access_token_expired',
    'identifier': '0000-0000-0000-0000',
    'orcidConnectEnabled': true
  });
  let user = FactoryGuy.make('user');

  this.set('user', user);
  this.set('currentUser', user);
  this.set('orcidAccount', orcidAccount);
  this.render(template);
  assert.elementFound('.orcid-access-expired');
  assert.elementFound('.remove-orcid');
});

test("user can click on trash icon, and say 'No, I don't want to remove my ORCID record'", function(assert){
  // Simulate user saying 'No' in the confirm dialog for removing their
  // ORCID record
  let confirm = sinon.stub().returns(false);
  this.set('confirm', confirm);

  let orcidAccount = FactoryGuy.make('orcid-account', {
    'status': 'authenticated',
    'identifier': '0000-0000-0000-0000'
  });

  assert.ok(orcidAccount.clearRecord, "clearRecord exists");
  orcidAccount.clearRecord = sinon.stub()

  this.set('orcidAccount', orcidAccount);
  this.render(template);
  this.$('.remove-orcid').click();
  assert.spyCalledWith(confirm, ["Are you sure you want to remove your ORCID record?"]);
  assert.spyNotCalled(orcidAccount.clearRecord, "clearRecord was not called.");
});

test("user can click on trash icon, and say 'Yes, I do want to remove my ORCID record'", function(assert){
  $.mockjax({
    url: "/api/orcid_accounts/1/clear",
    type: 'PUT',
    status: 200,
    responseText: { "orcid_account": {"id":1, "identifier":null} }}
  );

  // Simulate user saying 'Yes' in the confirm dialog for removing their
  // ORCID record
  let confirm = sinon.stub().returns(true);
  this.set('confirm', confirm);

  let orcidAccount = FactoryGuy.make('orcid-account', {
    'status': 'authenticated',
    'identifier': '0000-0000-0000-0000',
    'orcidConnectEnabled': true
  });

  this.set('orcidAccount', orcidAccount);
  this.render(template);
  this.$('.remove-orcid').click();

  // return wait().then(...) is used so a promise can be resolved for the
  // above mocked out HTTP PUT to /api/orcid_accounts/1/clear,
  return wait().then(() => {
    assert.spyCalledWith(confirm, ["Are you sure you want to remove your ORCID record?"]);

    // The promise returned by the restless call inside of clearRecord is resolving after the test runs :(
    assert.textPresent('.orcid-not-linked > button', 'Connect or create your ORCID ID');
  });
});

var noUserTemplate = hbs`{{orcid-connect user=user currentUser=currentUser orcidAccount=orcidAccount confirm=confirm journal=1 canRemoveOrcid=true}}`;

test("component works when user is not set and then set", function(assert) {
  let orcidAccount = FactoryGuy.make('orcid-account', {
    'status': 'access_token_expired',
    'identifier': '0000-0000-0000-0000'
  });

  let user = FactoryGuy.make('user', {
    id: '1'
  });

  this.set('currentUser', user);

  this.render(noUserTemplate);
  assert.elementNotFound('.orcid-wrapper');
  this.set('user', user);
  this.set('orcidAccount', orcidAccount);
  assert.elementFound('.orcid-wrapper');
});

test("users are only allowed to link their ORCID accounts", function(assert) {
  let user = FactoryGuy.make('user', {
    id: '1'
  });

  let viewer = FactoryGuy.make('user', {
    id: '2'
  });

  this.set('currentUser', viewer);

  this.render(noUserTemplate);
  assert.elementNotFound('.orcid-wrapper');
  this.set('user', user);
  assert.elementNotFound('.orcid-wrapper');
});
