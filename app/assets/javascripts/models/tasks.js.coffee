a = DS.attr
ETahi.Task = DS.Model.extend
  title: a('string')
  type: a('string')
  completed: a('boolean')
  role: a('string')
  body: a('string')
  comments: DS.hasMany('comment')
  isMessage: Ember.computed.equal('type', 'MessageTask')
  phase: DS.belongsTo('phase')
  assignees: DS.hasMany('user')
  assignee: DS.belongsTo('user')
  paper: Ember.computed.alias('phase.paper')
  paperTitle: a('string')

ETahi.PaperReviewerTask = ETahi.Task.extend
  reviewer: DS.belongsTo('user')

ETahi.PaperEditorTask = ETahi.Task.extend
  editors: DS.hasMany('user')
  editor: DS.belongsTo('user')

ETahi.PaperAdminTask = ETahi.Task.extend
  admins: DS.hasMany('user')
  admin: DS.belongsTo('user')

ETahi.AuthorsTask = ETahi.Task.extend
  authors: Ember.computed.alias('phase.paper.authorsArray')

ETahi.DeclarationTask = ETahi.Task.extend
  declarations: Ember.computed.alias('paper.declarations')

ETahi.FigureTask = ETahi.Task.extend
  figures: Ember.computed.alias('paper.figures')

ETahi.MessageTask = ETahi.Task.extend
  participants: DS.hasMany('user')
  comments: DS.hasMany('comment')
  paper: Ember.computed.alias('phase.paper')

ETahi.RegisterDecisionTask = ETahi.Task.extend
  decisionLetters: a('string')
  acceptedLetterTemplate: (->
    JSON.parse(@get('decisionLetters')).Accepted
  ).property 'decisionLetters'
  rejectedLetterTemplate: (->
    JSON.parse(@get('decisionLetters')).Rejected
  ).property 'decisionLetters'
  reviseLetterTemplate: (->
    JSON.parse(@get('decisionLetters')).Revise
  ).property 'decisionLetters'


ETahi.TechCheckTask = ETahi.Task.extend()
ETahi.ReviewerReportTask = ETahi.Task.extend()
ETahi.UploadManuscriptTask = ETahi.Task.extend()
