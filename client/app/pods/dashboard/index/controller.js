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
import pluralizeString from 'tahi/lib/pluralize-string';

export default Ember.Controller.extend({
  restless: Ember.inject.service('restless'),
  featureFlag: Ember.inject.service(),
  papers: [],
  unreadComments: [],
  invitationsInvited: Ember.computed.alias('currentUser.invitationsInvited'),
  invitationsNeedsUserUpdate: Ember.computed.alias('currentUser.invitationsNeedsUserUpdate'),
  invitationsPendingDecline: Ember.computed.filter(
    'invitationsNeedsUserUpdate',
    function(invitation) {
      return invitation.get('declined') && invitation.get('pendingFeedback');
    }
  ),

  hasPapers:         Ember.computed.notEmpty('papers'),
  hasActivePapers:   Ember.computed.notEmpty('activePapers'),
  hasInactivePapers: Ember.computed.notEmpty('inactivePapers'),
  hasPostedPreprints: Ember.computed.notEmpty('preprints'),
  activePageNumber:   1,
  inactivePageNumber: 1,
  activePapersVisible: true,
  inactivePapersVisible: true,
  preprintsVisible: true,
  invitationsLoading: false,
  relatedAtSort: ['relatedAtDate:desc'],
  updatedAtSort: ['updatedAt:desc'],
  sortedNonDraftPapers: Ember.computed.sort('activeNonDrafts', 'relatedAtSort'),
  sortedDraftPapers:    Ember.computed.sort('activeDrafts', 'updatedAtSort'),
  sortedInactivePapers: Ember.computed.sort('inactivePapers', 'updatedAtSort'),
  activeDrafts:         Ember.computed.filterBy(
                          'activePapers', 'publishingState', 'unsubmitted'
                        ),
  activeNonDrafts:      Ember.computed.filter('activePapers', function(paper) {
                          return paper.get('publishingState') !== 'unsubmitted';
                        }),
  activePapers:         Ember.computed.filterBy('papers', 'active', true),
  inactivePapers:       Ember.computed.filterBy('papers', 'active', false),
  preprints: Ember.computed.filterBy('papers', 'preprintDashboard', true),

  totalActivePaperCount: Ember.computed.alias('activePapers.length'),
  totalInactivePaperCount: Ember.computed.alias('inactivePapers.length'),
  totalPreprintCount: Ember.computed.alias('preprints.length'),
  activeManuscriptsHeading: Ember.computed('totalActivePaperCount', function() {
    return 'Active ' +
            pluralizeString('Manuscript', this.get('totalActivePaperCount')) +
            ' (' +
            this.get('totalActivePaperCount') +
            ')';
  }),
  inactiveManuscriptsHeading: Ember.computed('totalInactivePaperCount',
    function() {
      const count = this.get('totalInactivePaperCount');
      return 'Inactive ' + pluralizeString('Manuscript', count) +
             ' (' + this.get('totalInactivePaperCount') + ')';
    }
  ),
  postedPreprintsHeading: Ember.computed('totalPreprintCount', function() {
    return `Preprints (${this.get('totalPreprintCount')})`;
  }),
  showNewManuscriptOverlay: false,

  hideInvitationsOverlay() {
    this.set('showInvitationsOverlay', false);
  },

  messagePerRole(role, journalName) {
    let msg;
    if (role === 'Reviewer') {
      msg = `Thank you for agreeing to review for ${journalName}.`;
    } else {
      msg = `Thank you for agreeing to be an ${role} on this ${journalName} manuscript.`;
    }
    this.flash.displayRouteLevelMessage('success', msg);
  },

  actions: {
    toggleActiveContainer() {
      this.toggleProperty('activePapersVisible');
    },

    toggleInactiveContainer() {
      this.toggleProperty('inactivePapersVisible');
    },

    togglePreprintContainer() {
      this.toggleProperty('preprintsVisible');
    },

    showInvitationsOverlay() {
      this.set('showInvitationsOverlay', true);
    },

    hideInvitationsOverlay() {
      this.get('invitationsPendingDecline').forEach((invitation) => {
        invitation.decline();
      });
      this.hideInvitationsOverlay();
    },

    declineInvitation(invitation) {
      return invitation.decline();
    },

    acceptInvitation(invitation) {
      this.set('invitationsLoading', true);
      return this.get('restless').putUpdate(invitation, '/accept').then(()=> {
        this.hideInvitationsOverlay();
        this.transitionToRoute('paper.index', invitation.get('paperShortDoi')).then(() => {
          let role = invitation.get('inviteeRole');
          let journalName = invitation.get('journalName');
          this.messagePerRole(role, journalName);
        });
      }).finally(() => { this.set('invitationsLoading', false); });
    },

    showNewManuscriptOverlay() {
      const journals = this.store.findAll('journal');
      const paper = this.store.createRecord('paper', {
        journal: null,
        paperType: null,
        editable: true,
        body: ''
      });

      this.setProperties({
        journals: journals,
        newPaper: paper,
        journalsLoading: true
      });

      journals.then(()=> { this.set('journalsLoading', false); });

      this.set('showNewManuscriptOverlay', true);
    },

    // Set the "visible=" flag linked to an overlay to false. E.g., "showNewManuscriptOverlay"
    hideOverlay(name) {
      let flagName = 'show' + name + 'Overlay';
      this.set(flagName, false);
    },

    newManuscriptCreated(manuscript, template) {
      this.setProperties({
        showNewManuscriptOverlay: false,
        isUploading: false
      });

      const preprintFeatureFlagEnabled = this.get('featureFlag').value('PREPRINT');

      if (template.is_preprint_eligible && template.task_names.includes('Preprint Posting') && preprintFeatureFlagEnabled) {
        this.set('showPreprintOverlay', true);
      } else {
        this.transitionToRoute('paper.index', manuscript, {
          queryParams: { firstView: 'true' }
        });
      }
    },

    offerPreprintComplete() {
      this.send('hideOverlay', 'Preprint');
      let manuscript = this.get('newPaper');
      manuscript.reload();
      this.transitionToRoute('paper.index', manuscript, {
        queryParams: { firstView: 'true' }
      });
    }
  }
});
