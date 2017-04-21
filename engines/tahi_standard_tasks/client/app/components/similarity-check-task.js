import TaskComponent from 'tahi/pods/components/task-base/component';
import Ember from 'ember';

export default TaskComponent.extend({
  flash: Ember.inject.service(),
  restless: Ember.inject.service(),
  classNames: ['similarity-check-task'],
  latestVersionedText: Ember.computed.alias('task.paper.latestVersionedText'),

  actions: {
    confirmGenerateReport() {
      this.set('confirmVisible', true);
    },
    cancel() {
      this.set('confirmVisible', false);
    },
    generateReport() {
      this.get('task.paper.versionedTexts').then(() => {
        debugger;
        const similarityCheck = this.get('store').createRecord('similarity-check', {
          versionedText: this.get('latestVersionedText')
        });
        similarityCheck.save();
      });
    }
  }
});
