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
import { moduleFor, test } from 'ember-qunit';

let pusherStub, pusherFailureMessagesStub, flashStub;

moduleFor('controller:application', 'Unit | Controller | application', {
  integration: true,
  beforeEach: function() {
    pusherStub = Ember.Object.create({pusher: { connection: { state: 'connecting' } }});
    pusherFailureMessagesStub = { failed: 'f', unavailable: 'u', connecting: 'c', disconnected: 'd' };
    flashStub = Ember.Object.create({
      systemLevelMessages: Ember.A(),
      displaySystemLevelMessage(type, text) {
        this.get('systemLevelMessages').pushObject({ text: text, type: type });
      },
      removeSystemLevelMessage(message) {
        this.get('systemLevelMessages').removeObject(message);
      }
    });
  }
});

function updatePusher(connectionState) {
  pusherStub.set('pusher.connection.state', connectionState);
  pusherStub.set('isDisconnected', connectionState !== 'connected');
}
function simulateConnectingCompleted(connectionState, controller){
  // faking it because I can't get the handlePusherConnecting task to perform
  updatePusher(connectionState);
  controller.handlePusherConnectingCompleted();
}

test('Slanger notifications - happy path', function(assert) {
  assert.expect(3);
  let complete = assert.async();

  pusherStub.set('pusher.connection.state', 'connecting');
  let controller = null;
  Ember.run(() => {
    controller = this.subject({
      pusher: pusherStub,
      flash: flashStub,
      pusherFailureMessages: pusherFailureMessagesStub
    });

    assert.ok(controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [], 'flashes no connection messages');
  });
  Ember.run(() => {
    pusherStub.set('pusher.connection.state', 'connected');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [], 'flashes no connection messages');
    complete();
  });
});

test('Slanger notifications - failed to connect', function(assert) {

  assert.expect(4);
  let complete = assert.async();

  updatePusher('connecting');
  let controller = null;
  Ember.run(() => {
    controller = this.subject({
      pusher: pusherStub,
      flash: flashStub,
      pusherFailureMessages: pusherFailureMessagesStub
    });

    assert.ok(controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'c'}],
      'flashes connecting message');
  });
  Ember.run(() => {
    simulateConnectingCompleted('unavailable', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'flashes unavailable message');
  });
  Ember.run(() => {
    pusherStub.set('pusher.connection.state', 'failed');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'flashes unavailable because we can\'t see a change between two disconnected states');
    complete();
  });
});

test('Slanger notifications - spotty but ultimately able to connect', function(assert) {

  assert.expect(11);
  let complete = assert.async();

  updatePusher('connecting');
  let controller = null;
  Ember.run(() => {
    controller = this.subject({
      pusher: pusherStub,
      flash: flashStub,
      pusherFailureMessages: pusherFailureMessagesStub
    });

    assert.ok(controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'c'}],
      'flashes connecting message');
  });
  Ember.run(() => {
    simulateConnectingCompleted('connected', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [], 'flashes no connection messages');
  });
  Ember.run(() => {
    updatePusher('connecting');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'c'}],
      'flashes connecting message');
  });
  Ember.run(() => {
    simulateConnectingCompleted('unavailable', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'flashes unavailable message');
  });
  Ember.run(() => {
    updatePusher('connecting');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'no connecting message because we can\'t see a change between two disconnected states');
  });
  Ember.run(() => {
    simulateConnectingCompleted('connected', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'flashes keeps unavailable message even after connecting to encourage user to reload');
  });
  Ember.run(() => {
    updatePusher('connecting');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'),
      [{type: 'error', text: 'u'}, {type: 'error', text: 'c'}],
      'flashes connecting and unavailable messages');
  });
  Ember.run(() => {
    simulateConnectingCompleted('unavailable', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'flashes removes the connecting message');
  });
  Ember.run(() => {
    updatePusher('connecting');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'no connecting message because we can\'t see a change between two disconnected states');
  });
  Ember.run(() => {
    simulateConnectingCompleted('connected', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'u'}],
      'flashes only one unavailable message after reconnecting twice');
    complete();
  });
});

test('Slanger notifications - browser doesnt support web sockets', function(assert) {

  assert.expect(3);
  let complete = assert.async();

  updatePusher('connecting');
  let controller = null;
  Ember.run(() => {
    controller = this.subject({
      pusher: pusherStub,
      flash: flashStub,
      pusherFailureMessages: pusherFailureMessagesStub
    });

    assert.ok(controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'c'}],
      'flashes connecting message');
  });
  Ember.run(() => {
    simulateConnectingCompleted('failed', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'f'}],
      'flashes disconnected message');
    complete();
  });
});

test('Slanger notifications - intentional disconnect', function(assert) {

  assert.expect(4);
  let complete = assert.async();

  updatePusher('connecting');
  let controller = null;
  Ember.run(() => {
    controller = this.subject({
      pusher: pusherStub,
      flash: flashStub,
      pusherFailureMessages: pusherFailureMessagesStub
    });

    assert.ok(controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'c'}],
      'flashes connecting message');
  });

  Ember.run(() => {
    updatePusher('connected');
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [], 'flashes connection messages are empty');
  });

  Ember.run(() => {
    simulateConnectingCompleted('disconnected', controller);
    assert.deepEqual(controller.get('flash').get('systemLevelMessages'), [{type: 'error', text: 'd'}],
      'flashes disconnected message');
    complete();
  });
});
