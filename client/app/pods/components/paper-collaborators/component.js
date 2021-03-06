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

const { computed } = Ember;
const { setDiff } = computed;

export default Ember.Component.extend(EscapeListenerMixin, {
  selectedCollaborator: null,
  paper: null,
  initialCollaborations: null,
  collaborations: null,

  store: Ember.inject.service(),

  addedCollaborations: setDiff('collaborations', 'initialCollaborations'),
  removedCollaborations: setDiff('initialCollaborations', 'collaborations'),

  collaborators: computed('collaborations.[]', function() {
    return this.get('collaborations').mapBy('user');
  }),

  foundCollaborators: null,

  select2RemoteSource: Ember.computed(function(){
    let collaborators = this.get('collaborators');

    let paperId = this.get('paper.id');
    let url = `/api/filtered_users/users/${paperId}`;

    let existingCollaborator = (user) => {
      return !!collaborators.findBy('id', user.id.toString());
    };

    return {
      url: url,
      dataType: 'json',
      quietMillis: 500,
      data: function(term) {
        return { query: term };
      },
      results: (data) => {
        // data.users contains more fields than we're using
        // directly below, and we'll need those fields later.  we're
        // storing them off for that purpose.
        this.set('foundCollaborators', data.users);
        const selectableUsers = data.users.map(function(user){
          return {
            id: user.id,
            text: user.full_name
          };
        }).reject(existingCollaborator);

        return { results: selectableUsers };
      }
    };
  }),

  init() {
    this._super(...arguments);

    const collaborations = this.get('paper.collaborations') || [];
    this.setProperties({
      collaborations: collaborations,
      initialCollaborations: collaborations.slice()
    });
  },

  actions: {
    addNewCollaborator(newCollaboratorData) {
      const paper = this.get('paper');
      const store = this.get('store');

      let collaborator = this.get('foundCollaborators').findBy('id', newCollaboratorData.id);
      let newCollaborator = store.findOrPush('user', collaborator);

      // if this collaborator's record was previously removed from the paper
      // make sure we use THAT one and not a new record.

      const existingRecord = store.peekAll('collaboration').find(function(c) {
        return c.get('oldPaper') === paper && c.get('user') === newCollaborator;
      });

      const newCollaboration = existingRecord || store.createRecord(
        'collaboration',
        {
          paper: paper,
          user: newCollaborator
        }
      );

      this.get('collaborations').addObject(newCollaboration);
    },

    removeCollaborator(collaborator) {
      const collaboration = this.get('collaborations')
                                .findBy('user', collaborator);

      // since the relationship between paper and collaboration is
      // a proper hasMany, if we remove the collaboration from the papers'
      // collection of them ember will also unset the paper field on
      // the collaboration. If the user tries to re-add that collaborator
      // to the paper without reloading we need to do some extra checking
      // to make sure that ember doesn't create a new record but rather
      // uses the one we just removed here.
      collaboration.set('oldPaper', collaboration.get('paper'));
      this.get('collaborations').removeObject(collaboration);
      this.set('selectedCollaborator', null);
    },

    cancel() {
      const collaborations = this.get('collaborations');
      // we have to remove/add the changed collaborations from
      // their associations individually
      this.get('removedCollaborations').forEach(function(c) {
        return collaborations.addObject(c);
      });

      this.get('addedCollaborations').forEach(function(c) {
        return collaborations.removeObject(c);
      });

      this.attrs.close();
    },

    save() {
      const added = this.get('addedCollaborations');
      const removed = this.get('removedCollaborations');

      const addPromises = added.map(function(collaboration) {
        return collaboration.save();
      });

      const deletePromises = removed.map(function(collaboration) {
        return collaboration.destroyRecord();
      });

      Ember.RSVP.all(addPromises.concat(deletePromises)).then(()=> {
        this.attrs.close();
      });
    },

    close() {
      this.attrs.close();
    }
  }
});
