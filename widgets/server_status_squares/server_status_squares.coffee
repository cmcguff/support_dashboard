class Dashing.ServerStatusSquares extends Dashing.Widget

  onData: (data) ->
    $(@node).fadeOut().fadeIn()
    color = if data.result == 1 then "#96BF48" else "#BF4848"
    $(@get('node')).css('background-color', "#{color}")