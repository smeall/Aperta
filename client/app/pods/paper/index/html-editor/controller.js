import Ember from 'ember';
import PaperBase from 'tahi/mixins/controllers/paper-base';
import PaperIndex from 'tahi/mixins/controllers/paper-index';
import Discussions from 'tahi/mixins/discussions/route-paths';

export default Ember.Controller.extend(PaperBase, PaperIndex, Discussions, {
  subRouteName: 'index',

  // Note: we create the editor component via name
  // so that we can override that property when running tests
  // to use a mock implementation
  editorComponent: "tahi-editor-ve",

  // initialized by paper/index/view
  toolbar: null,
  hasOverlay: false,
  versioningMode: false,

  // used to recover a selection when returning from another context (such as figures)
  isEditing: Ember.computed.alias('lockedByCurrentUser'),

  paperBodyDidChange: Ember.observer('model.body', function() {
    this.updateEditor();
  }),

  startEditing() {
    this.acquireLock();
    this.connectEditor();
  },

  stopEditing() {
    this.disconnectEditor();
    this.releaseLock();
  },

  acquireLock() {
    // Note:
    // when the paper is saved, the server knows who acquired the lock
    // (this is required for the heartbeat to work)
    // when the save succeeds, we send the `startEditing` action,
    // which is defined on `paper/index/route`, which now starts the heartbeat
    // Thus, to acquire the lock it is necessary to
    // 1. set model.lockedBy = this.currentUser
    // 2. save the model, which sends the updated lockedBy to the server
    // 3. let the router know that we are starting editing
    let paper = this.get('model');
    paper.set('lockedBy', this.currentUser);
    this.get('editor').writeToModel();
    paper.save().then(()=>{
      this.send('startEditing');
    });
  },

  releaseLock() {
    let paper = this.get('model');
    paper.set('lockedBy', null);
    paper.save().then(() => {
      this.disconnectEditor();
    });
  },

  updateEditorLockState: Ember.observer('lockedByCurrentUser', function() {
    if (this.get('lockedByCurrentUser')) {
      this.connectEditor();
    } else {
      this.disconnectEditor();
    }
  }),

  updateEditor() {
    let editor = this.get('editor');
    if (editor) {
      editor.update();
    }
  },

  savePaper() {
    if (!this.get('model.editable')) {
      return;
    }
    let editor = this.get('editor');
    if(Ember.isEmpty(editor)) { return; }

    let paper = this.get('model');
    editor.writeToModel();
    if (paper.get('isDirty')) {
      return paper.save().then(()=>{
        this.set('saveState', true);
        this.set('isSaving', false);
      });
    } else {
      this.set('isSaving', false);
      return paper.save();
    }
  },

  connectEditor() {
    let editor = this.get('editor');
    if(editor) {
      editor.enable();
    }
  },

  disconnectEditor() {
    let editor = this.get('editor');
    if(editor) {
      editor.disable();
    }
  },

  actions: {
    lock() {
      this.acquireLock();
    },
    unlock() {
      this.releaseLock();
    }
  },

  hideEditor: Ember.computed('model.editable', 'versioningMode',
    function() {
      return !(this.get('model.editable')) || this.get('versioningMode');
    })
});