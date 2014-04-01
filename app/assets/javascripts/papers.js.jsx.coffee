###* @jsx React.DOM ###
Tahi.papers =
  init: ->
    $('#add_author').on 'click', (e) ->
      e.preventDefault()
      li = $('<li class="author">')
      li.html $('#author-template').html()
      li.appendTo $('ul.authors')
    @fixArticleControls()
    @instantiateEditables()
    @initAuthors()

  fixArticleControls: ->
    $('#control-bar-container').scrollToFixed()
    $('#toolbar').scrollToFixed(marginTop: $('#control-bar-container').outerHeight(true))
    $('#tahi-container > main > aside > div').scrollToFixed
      marginTop: $('#control-bar-container').outerHeight(true)
      unfixed: ->
        $(this).css('top', '0px')

  instantiateEditables: ->
    if $("[contenteditable]").length > 0
      ve.init.platform.setModulesUrl( '/visual-editor/modules' )
      container = $('<div>')
      pageHtml = $('#paper-body').html()
      $('#paper-body').html(container)

      target = new ve.init.sa.Target(
        container,
        ve.createDocumentFromHtml(pageHtml)
      )

      window.visualEditor = target

      @titleEditable = new Tahi.PlaceholderElement($('#paper-title[contenteditable]')[0])

  bodyContent: ->
    bodyContentWrapper = $('<div/>')
    ve.dm.converter.getDomSubtreeFromModel(visualEditor.surface.getModel().getDocument(), bodyContentWrapper[0])
    bodyContentWrapper.html()

  savePaper: (url) ->
    $.ajax
      url: url
      method: "POST"
      data:
        _method: "patch"
        paper:
          title: @titleEditable.getText()
          body: @bodyContent()
          # abstract: @abstractEditable.getText()
          # short_title: @shortTitleEditable.getText()
    false

  initAuthors: ->
    @authors = @components.Authors
      authors: $('#paper-authors').data('authors')
    mountPoint = document.getElementById('paper-authors')
    React.renderComponent @authors, mountPoint if mountPoint

  components:
    Authors: React.createClass
      getInitialState: ->
        authors: []

      componentWillMount: ->
        @setState authors: @props.authors

      render: ->
        if @state.authors.length > 0
          authorNames = @state.authors.map (author) ->
            "#{author.first_name} #{author.last_name}"
          `<span>{authorNames.join(', ')}</span>`
        else
          `<span className='placeholder'>Click here to add authors</span>`

      componentDidMount: ->
        @token = Tahi.pubsub.subscribe 'update_authors', (topic, authors) =>
          @setState authors: authors

      componentWillUnmount: ->
        Tahi.pubsub.unsubscribe @token
