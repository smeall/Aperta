`import Ember from 'ember'`
`import RESTless from 'tahi/services/rest-less'`
`import Utils from 'tahi/services/utils'`

PaperRoute = Ember.Route.extend
  model: (params) ->
    @store.fetchById('paper', params.paper_id)

  setupController: (controller, model) ->
    controller.set('model', model)

  actions:
    addContributors: ->
      paper = @modelFor('paper')
      collaborations = paper.get('collaborations') || []
      controller = @controllerFor('overlays/showCollaborators')
      controller.setProperties
        paper: paper
        collaborations: collaborations
        initialCollaborations: collaborations.slice()
        allUsers: @store.find('user')

      @render('overlays/showCollaborators',
        into: 'application'
        outlet: 'overlay'
        controller: controller)

    showActivity: (name) ->
      paper = @modelFor('paper')
      controller = @controllerFor 'overlays/activity'
      controller.set 'isLoading', true

      RESTless.get("/api/papers/#{paper.get('id')}/activity/#{name}").then (data) =>
        controller.setProperties
          isLoading: false
          model: Utils.deepCamelizeKeys(data.feeds)

      @render 'overlays/activity',
        into: 'application',
        outlet: 'overlay',
        controller: controller

`export default PaperRoute`
