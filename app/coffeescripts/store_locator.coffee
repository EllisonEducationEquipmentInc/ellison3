class document.StoreLocator
  constructor: (store_locator_title, lat, lng, zoom)->
    $(document).ready(->
      $(".tab-block").tabs()
      $(".tab-block").tabs "select", 1
      $(".tab-block").bind "tabsselect", (event, ui) ->
        if ui.index is 0
          $("#tab-head span").text "Online Retailers"
          $("#stores > .storeframe").toggle()
          $("#map_search_submit").toggle()
          $("#stores > hr").toggle()
        else if ui.index is 1
          $("#tab-head span").text store_locator_title
          $("#stores > .storeframe").toggle()
          $("#map_search_submit").toggle()
          $("#stores > hr").toggle()

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
        state_is_blank = $("#state").val().length == 0
        name_is_blank = $("#name").val().length == 0
        country_val = $("#country").val()

        if country_val is "United States" and state_is_blank and $("#zip_code").val().length == 0 and name_is_blank
          alert "please select state or zip code or search by name"
          return false
        else if country_val is "United States" and $("#zip_code").val().length < 5 and state_is_blank and name_is_blank
          alert "invalid zip code"
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
      $("#map_search_submit").removeClass("without_us_or_uk")
      $(".us_only").show()
      $(".us_or_uk_only").show()
      $(".zipcode").addClass("zipcode_us")
      $(".zipcode").removeClass("postcode_uk")
      $(".zipcode h3").text("Search by Zip Code:")
    else if $("#country").val() is "United Kingdom"
      $("#map_search_submit").removeClass("without_us_or_uk")
      $(".us_only").hide()
      $(".us_or_uk_only").show()
      $(".zipcode").addClass("postcode_uk")
      $(".zipcode").removeClass("zipcode_us")
      $(".zipcode h3").text("Search by Postal Code:")
    else
      $("#map_search_submit").addClass("without_us_or_uk")
      $(".us_only").hide()
      $(".us_or_uk_only").hide()