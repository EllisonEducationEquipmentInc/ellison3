class document.StoreLocator
  constructor: (store_locator_title, lat, lng, zoom)->
    $(document).ready(->
      $(".tab-block").tabs()
      $(".tab-block").tabs "select", 1
      $(".tab-block").bind "tabsselect", (event, ui) ->
        if ui.index is 0
          $("#tab-head span").text "Online Retailers"
        else $("#tab-head span").text store_locator_title  if ui.index is 1

      toggle_store_fields()
      $.getScript "/javascripts/vendor/jquery.metadata.js", ->
        $("#map").jMapping
          default_point:
            lat: lat
            lng: lng

          default_zoom_level: zoom
          link_selector: ".map-link"

      $("#country").change ->
        toggle_store_fields()

      $("#map_search_submit").click ->
        if $("#country").val() is "United States" and $("#zip_code").val().length < 5
          alert "invalid zip code"
          return false
        if $(".brands:checked").length < 1
          alert "please select at least one brand"
          return false
        $.ajax
          url: "/index/update_map?" + $(this).parents("form").serialize()
          success: (html) ->
            $("#map-side-bar").html html
            $("#map").jMapping "update"
            $("#map").data("jMapping").map.setZoom 4  if html.length < 20
            $(".info-box").show()
            $(".info-box h3").css "cursor", "pointer"
            $("#map").data("jMapping").map.setZoom 15  if $("#map").data("jMapping").map.zoom > 15

        false

      $("#map_search_submit").trigger "click"  unless $("#country").val() is "United States").bind "afterMapping.jMapping", (e, m) ->
        setTimeout "$('#map').data('jMapping').map.setZoom(4)", 1200

  toggle_store_fields = ->
    if $("#country").val() is "United States"
      $(".us_only").show()
    else
      $(".us_only").hide()