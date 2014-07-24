moduleFor 'route:paper', 'Unit: route/Paper',
  needs: ['model:paper', 'route:paper'],
  teardown: -> ETahi.reset()
  setup: ->
    setupApp()
    @subject().store = find: sinon.stub()

test 'the model should be paper', ->
  @subject().model paper_id: 123
  ok @subject().store.find.calledWith 'paper', 123
