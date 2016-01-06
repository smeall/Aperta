import Ember from 'ember';
import FileUpload from 'tahi/models/file-upload';
import extensionFont from 'tahi/lib/extension-font';

export default Ember.Component.extend({
  classNames: ['attachment-manager'],
  description: 'Please select a file.',
  buttonText: 'Upload File',
  fileUpload: null,
  uploadInProgress: Ember.computed.notEmpty('fileUpload'),
  currentUpload: null,
  multiple: false,
  hasUploads: Ember.computed.notEmpty('attachments'),
  showAddButton: Ember.computed('multiple', 'hasUploads', function() {
    if (this.get('hasUploads') && !this.get('multiple')) return false;
    return true;
  }),

  init() {
    this._super(...arguments);
    Ember.assert('Please provide filePath property', this.get('filePath'));
    if (!this.get('attachments')) this.set('attachments', []);
  },

  actions: {

    fileAdded(file){
      this.setProperties({
        fileUpload: FileUpload.create({ file: file }),
        currentUpload: Ember.Object.create({fileName: file.name})
      });
    },

    uploadProgress(data) {
      this.get('fileUpload').setProperties({
        dataLoaded: data.loaded,
        dataTotal: data.total
      });
    },

    uploadFinished(s3Url){
      this.get('attachments').addObject(this.get('currentUpload'));
      this.setProperties({fileUpload: null, currentUpload: null});
      if (this.attrs.uploadFinished) {
        this.attrs.uploadFinished(s3Url);
      }
    },

    uploadFailed(reason){
     console.log('uploadFailed', reason);
    }
  }
});
