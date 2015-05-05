`import Ember from 'ember';`
`import PaperBaseMixin from 'tahi/mixins/controllers/paper-base';`
`import PaperEditMixin from 'tahi/mixins/controllers/paper-edit';`
`import TahiEditorExtensions from 'tahi-editor-extensions/index';`

`import VeFigureCollectionAdapter from 'tahi/pods/paper/edit/adapters/ve-figure-collection-adapter';`
`import TableCollectionAdapter from 'tahi/pods/paper/edit/adapters/table-collection-adapter';`

Controller = Ember.Controller.extend PaperBaseMixin, PaperEditMixin,
  # initialized by paper/edit/view
  toolbar: null

  # used to recover a selection when returning from another context (such as figures)
  isEditing: Ember.computed.alias('lockedByCurrentUser')
  lastEditorState: null

  figuresAdapter: null

  hasOverlay: false

  paperBodyDidChange: ( ->
    unless @get('lockedByCurrentUser')
      @updateEditor()
  ).observes('model.body')

  # called by ember-cli-visualeditor/components/visual-editor (see template for hook)
  setupEditor: (editor) ->
    FigureLabelGenerator = require('tahi-editor-extensions/figures/model/figure-label-generator')['default']
    # register extensions
    editor.registerExtensions(TahiEditorExtensions)
    editor.registerExtension(
      afterDocumentCreated: (documentModel) ->
        figuresIndex = documentModel.getIndex('figure-nodes')
        tablesIndex = documentModel.getIndex('table-nodes')
        figureLabelGenerator = new FigureLabelGenerator(figuresIndex)
        tableLabelGenerator = new FigureLabelGenerator(tablesIndex, 'Table')
        documentModel.addService('figure-labels', figureLabelGenerator)
        documentModel.addService('table-labels', tableLabelGenerator)
        documentModel.addService('main-document',
          get: ->
            return documentModel
        )
    )
    # load the document
    paper = this.get('model')
    doc = editor.getDocument()
    editor.fromHtml(paper.get('body'))

    figuresAdapter = VeFigureCollectionAdapter.create(
      controller: @
      paper: paper
      doc: doc
    ).connect()
    tableCollectionAdapter = TableCollectionAdapter.create(
      doc: doc
      paper: paper
      editor: editor
    )

    if @get('isEditing')
      editor.enable()
    else
      editor.disable()

    @set('editor', editor)
    @set('figuresAdapter', figuresAdapter)
    @set('tableCollectionAdapter', tableCollectionAdapter)
    editor.removeSelection()

  startEditing: ->
    @set('model.lockedBy', @currentUser)
    @get('model').save().then (paper) =>
      @connectEditor()
      @send('startEditing')
      @set('saveState', false)

  stopEditing: ->
    @set('model.body', @get('editor').toHtml())
    @set('model.lockedBy', null)
    @send('stopEditing')
    @disconnectEditor()
    @get('model').save().then (paper) =>
      @set('saveState', true)

  updateEditor: ->
    editor = @get('editor')
    if editor
      # HACK: need to enable the editor so that changes to the model are possible
      if not @get('isEditing')
        editor.enable()
      editor.fromHtml(@get('model.body'))
      if not @get('isEditing')
        editor.disable()

  updateToolbar: (newState) ->
    toolbar = @get('toolbar')
    if toolbar
      toolbar.updateState(newState)
      @set('lastEditorState', newState)

  savePaper: ->
    return unless @get('model.editable')
    editor = @get('editor')
    paper = @get('model')
    manuscriptHtml = editor.toHtml()
    paper.set('body', manuscriptHtml)
    if paper.get('isDirty')
      paper.save().then (paper) =>
        @set('saveState', true)
        @set('isSaving', false)
    else
      @set('isSaving', false)

  updateFigures: ->
    editor = @get('editor')
    # we need to allow model changes
    modelWasEnabled = editor.isModelEnabled()
    unless modelWasEnabled
      editor.enableModel()

    @get('figuresAdapter').loadFromModel()

    unless modelWasEnabled
      editor.disableModel()

  onDocumentChange: ->
    # HACK: in certain moments we need to inhibit saving
    # e.g., when updating a figure URL, the server provides a new figure URL
    # leading to an unfinite loop of updates.
    # See paper/edit/ve-figure-adapter
    unless @get('inhibitSave')
      @set('saveState', false)
      @savePaperDebounced()

  # enables handlers for document changes (saving) and selection changes (toolbar)
  connectEditor: ->
    @get('editor').connect @,
      "document-change": @onDocumentChange
      "state-changed": @updateToolbar

  disconnectEditor: ->
    @get('editor').disconnect @

  willDestroy: ( ->
    @_super()
    @get('figuresAdapter')?.dispose()
    @get('tableCollectionAdapter')?.destroy()
  )

`export default Controller;`
