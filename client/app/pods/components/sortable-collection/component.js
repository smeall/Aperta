import Ember from 'ember';

export default Ember.Component.extend({
  phase: null, // passed-in
  classNames: ['sortable'],
  classNameBindings: ['sortableNoCards'],
  attributeBindings: ['dataPhaseId:data-phase-id'],
  dataPhaseId: Ember.computed.alias('phase.id'),
  taskTemplates: Ember.computed.alias('phase.taskTemplates'),
  sortableNoCards: Ember.computed.empty('taskTemplates'),

  didInsertElement() {
    this._super();
    Ember.run.schedule("afterRender", this, "setupSortable");
  },

  updateTaskPositions(updatedPositions) {
    this.beginPropertyChanges();
    this.get('taskTemplates').forEach(function(task) {
      task.set('position', updatedPositions[task.get('id')]);
    });
    this.endPropertyChanges();
  },

  setupSortable() {
    const self = this;

    this.$().sortable({
      items: '.card',
      scroll: false,
      containment: '.columns',
      connectWith: '.sortable',

      update(event, ui) {
        let updatedPositions  = {};
        const senderPhaseId   = self.get('phase.id');
        const receiverPhaseId = ui.item.parent().attr('data-phase-id');
        const taskId = ui.item.find('.card-content').data('id');

        self.sendAction('itemUpdated', senderPhaseId, receiverPhaseId, taskId);

        $(this).find('.card-content').each(function(index) {
          updatedPositions[$(this).data('id')] = index + 1;
        });

        self.updateTaskPositions(updatedPositions);
      },

      start(event, ui) {
        // class added to set overflow: visible;
        $(ui.item).addClass('card--dragging')
                  .closest('.column-content')
                  .addClass('column-content--dragging');
      },

      stop(event, ui) {
        $(ui.item).removeClass('card--dragging')
                  .closest('.column-content')
                  .removeClass('column-content--dragging');
      }
    });
  }

});
