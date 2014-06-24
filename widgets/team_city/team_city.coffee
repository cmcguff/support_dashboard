class Dashing.TeamCity extends Dashing.Widget
  ready: ->
    @get('unordered')
    if @get('unordered')
      $(@node).find('ol').remove()
    else
      $(@node).find('ul').remove()
    @_checkStatus(@items[0].status, items[0].state)

  onData: (data) ->
    @_checkStatus(data.items[0].status, data.items[0].state)

  _checkStatus: (status, state) ->
    $(@node).removeClass('errored FAILURE SUCCESS running started finished')
    if state == "running"
      $(@node).addClass(state)
    else
      $(@node).addClass(status) 
