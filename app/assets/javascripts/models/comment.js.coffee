a = DS.attr
ETahi.Comment = DS.Model.extend
  commenter: DS.belongsTo('user')
  messageTask: DS.belongsTo('messageTask')
  body: a('string')
  createdAt: a('date')
  commentLook: DS.belongsTo('commentLook')
