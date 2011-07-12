$.fn.extend
  toggleView: (options) ->
    self = $.fn.toggleView
    settings = $.extend {}, self.defaults, options
    @each ->
      dom = $(this)
      return  if dom.data("toggleView")
      dom.data "toggleView", true
      self.init settings, dom

$.extend $.fn.toggleView,
  defaults:
    toggled_class: "toggled"
    state_attribute: "data-current-state"
    list_view_class: "listview"
    toggle_text: "%state% view"
    states: [ "grid", "list" ]
    collection_container: ".highlightable"
    initial_state: "grid"
    
  init: (settings, dom) ->
    @settings = settings
    @dom = dom
    @current_state = settings.initial_state
    @setInitialStateIfNeccessary()
    @connectToggleEvents()
  
  setInitialStateIfNeccessary: ->
    return  if @dom.attr("data-current-state") == @settings.initial_state
    @dom.text @settings.toggle_text.replace("%state%", @getOpposite())
    @dom.attr "data-current-state", @settings.initial_state
    if @settings.states.indexOf(@settings.initial_state) == 1
      @dom.addClass "toggled"
      $(@settings.collection_container).addClass "listview"
  
  toggle_state: ->
    that = this
    @dom.text that.settings.toggle_text.replace("%state%", that.current_state)
    @current_state = @getOpposite()
    @dom.attr "data-current-state", that.current_state
    if @settings.states.indexOf(@current_state) == 0
      @dom.removeClass "toggled"
    else
      @dom.addClass "toggled"
    $(window).unbind "hashchange"
    location.hash = $.param.fragment(location.hash, view: @current_state, 0)
    $(@settings.collection_container).fadeOut "fast", ->
      if that.settings.states.indexOf(that.current_state) == 0
        $(this).fadeIn("fast").removeClass "listview"
      else
        $(this).fadeIn("fast").addClass "listview"
      bind_hashchange()
  
  connectToggleEvents: ->
    that = this
    @dom.click ->
      that.toggle_state()
      false
  
  getOpposite: ->
    (if (@settings.states.indexOf(@current_state) == 0) then @settings.states[1] else @settings.states[0])
