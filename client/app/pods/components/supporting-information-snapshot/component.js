import Ember from 'ember';
import {
  namedComputedProperty
} from 'tahi/mixins/components/snapshot-named-computed-property';

const SIFileSnapshot = Ember.Object.extend({
  snapshot: null,
  file: namedComputedProperty('snapshot', 'file'),
  title: namedComputedProperty('snapshot', 'title'),
  caption: namedComputedProperty('snapshot', 'caption'),
  strikingImage: namedComputedProperty('snapshot', 'striking_image'),
  publishable: namedComputedProperty('snapshot', 'publishable'),
  fileHash: namedComputedProperty('snapshot', 'file_hash')
});

export default Ember.Component.extend({
  snapshot1: null,
  snapshot2: null,
  classNames: ['supporting-information-file-snapshot'],
  classNameBindings: ['added', 'snapshot1::removed'],
  siFile1: Ember.computed('snapshot1', function() {
    return SIFileSnapshot.create({snapshot: this.get('snapshot1')});
  }),

  siFile2: Ember.computed('snapshot2', function() {
    return SIFileSnapshot.create({snapshot: this.get('snapshot2')});
  }),

  added: Ember.computed('snapshot2', function() {
    // gotta check if the whole thing was deleted, not just absent
    // because we're viewing a single version.
    return this.get('snapshot2') && _.isEmpty(this.get('snapshot2'));
  }),

  fileHashChanged: Ember.computed(
    'siFile1.fileHash',
    'siFile2.fileHash',
    function() {
      return this.get('siFile1.fileHash') !== this.get('siFile2.fileHash');
    }
  )
});
