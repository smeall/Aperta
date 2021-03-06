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

import ENV from 'tahi/config/environment';
import Ember from 'ember';

export default {
  name: 'pusher-setup',
  after: 'current-user',
  initialize(instance) {
    let pusherService = instance.lookup('service:pusher');
    pusherService.setup(
      ENV.APP.PUSHER_OPTS.key,
      ENV.APP.PUSHER_OPTS.connection
    );
    let bugsnagService = instance.lookup('service:bugsnag');
    let pusher = pusherService.pusher;
    /*
    Tell somebody about Pusher error states
    =========================================
    Note: if pusher.connection starts in a bad state it will NOT emit
    any events. It will just start in a bad state. Events are only emitted
    if pusher.connection transitions from one known state to the next.

    Reference: https://pusher.com/docs/client_api_guide/client_connect
  */

    // Pusher is not supported by the browser. This implies that WebSockets are
    // not natively available and an HTTP-based transport could not be found.
    // This is not fired as an event, but set as the connection's state.
    if (Ember.isEqual(pusher.connection.state, 'failed')) {
      bugsnagService.notify(
        'PusherNotSupported',
        'Pusher.js is not supported by the browser'
      );
    }

    // The connection is unavailable. When the server is unavailable
    // on application load the pusher.connection starts out in the unavailable
    // state rather than transitioning to the unavailable state, so we must
    // check it first.
    if (Ember.isEqual(pusher.connection.state, 'unavailable')) {
      bugsnagService.notify(
        'PusherUnavailable',
        'Pusher.js service unavailable on app load'
      );
    }

    // The Pusher connection was previously connected and has now intentionally
    // been closed.
    pusher.connection.bind('disconnected', function() {
      if (!instance.isDestroying) {
        bugsnagService.notify('PusherDisconnected', 'Pusher.js has disconnected');
      }
    });

    // The connection has become unavailable. This implies that the
    // pusher.connection was in another state first. If the pusherjs server
    // is unavailable when the application loads then this will not be triggered.
    pusher.connection.bind('unavailable', function() {
      bugsnagService.notify(
        'PusherUnavailable',
        'Pusher.js service became unavailable during app use'
      );
    });

    instance.registry.injection('adapter', 'pusher', 'service:pusher');
    instance.registry.injection('controller', 'pusher', 'service:pusher');
    instance.registry.injection('route', 'pusher', 'service:pusher');
    instance.registry.injection(
      'service:notifications',
      'pusher',
      'service:pusher'
    );
  }
};
