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
import EscapeListenerMixin from 'tahi/mixins/escape-listener';
import { PropTypes } from 'ember-prop-types';

export default Ember.Component.extend(EscapeListenerMixin, {
  propTypes: {
    journal: PropTypes.EmberObject,
    success: PropTypes.func, // action, called when card is created
    close: PropTypes.func // action, called to close the overlay
  },

  classNames: ['admin-overlay'],
  name: '',
  scenario: '',
  errors: null,
  scenarioError: Ember.computed('errors', function() {
    return this.get('errors') && this.get('errors').has('scenario') ? 'labeled-input-with-errors-errored' : null;
  }),
  templateNames: Ember.computed('templates[]', function() {
    if (this.get('templates.length')) {
      return this.get('templates').mapBy('name');
    } else {
      return [];
    }
  }),

  store: Ember.inject.service(),

  actions: {
    close() {
      this.get('close')();
    },

    complete() {
      this.set('errors', null);
      let name = this.get('name') || '';
      const template = this.get('store').createRecord('letter-template', {
        name: name,
        journalId: this.get('journal.id'),
        scenario: this.get('scenario.name'),
        mergeFields: this.get('scenario.merge_fields')
      });

      let errors = template.get('errors');
      if (Ember.isBlank(this.get('scenario'))) errors.add('scenario', 'This field is required');

      if (Ember.isBlank(name)) errors.add('name', 'This field is required');
      if (this.get('templateNames').map(n => n.toLowerCase()).includes(name.toLowerCase())) {
        errors.add('name', 'That template name is taken for this journal. Please give your template a new name.');
      }

      if (template.get('errors.isEmpty')) {
        this.get('success')(template);
        this.get('close')();
      } else {
        this.set('errors', errors);
      }
    },

    valueChanged(newVal) {
      this.set('scenario', newVal);
    }
  }
});
