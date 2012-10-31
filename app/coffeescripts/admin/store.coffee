class document.AdminStore
  constructor: ->
    @country_dom = $("#store_country")
    @agent_type_dom = $("#store_agent_type")
    @representative_serving_dom = $(".representative_serving")

  country_dom = (dom = null) ->
    @country_dom ||= dom

  agent_type_dom = (dom = null) ->
    @agent_type_dom ||= dom

  representative_serving_dom = (dom = null) ->
    @representative_servig_dom ||= dom

  selected_agent_type = ->
    agent_type_dom().find(":selected").text()

  selected_country = ->
    country_dom().find(":selected").text()

  bind_agent_type = ->
    agent_type_dom().change ->
      verify_agent_type_country(selected_agent_type(), selected_country())

  bind_country = ->
    country_dom().change ->
      verify_agent_type_country(selected_agent_type(), selected_country())

  verify_agent_type_country = (agent_type, country) ->
    if agent_type == 'Sales Representative' and country == 'United States'
      show_representative_serving_states()
    else
      hide_representative_serving_states()

  show_representative_serving_states = ->
    representative_serving_dom().fadeIn('show')

  hide_representative_serving_states = ->
    representative_serving_dom().hide()

  bind_agent_type_and_country: ->
    country_dom(@country_dom)
    agent_type_dom(@agent_type_dom)
    representative_serving_dom(@representative_serving_dom)

    bind_agent_type()
    bind_country()
    verify_agent_type_country(selected_agent_type(), selected_country())
