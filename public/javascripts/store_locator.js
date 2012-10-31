(function() {

  document.StoreLocator = (function() {
    var toggle_store_fields;

    function StoreLocator(store_locator_title, lat, lng, zoom) {
      $(document).ready(function() {
        $(".tab-block").tabs();
        $(".tab-block").tabs("select", 1);
        $(".tab-block").bind("tabsselect", function(event, ui) {
          if (ui.index === 0) {
            $("#tab-head span").text("Online Retailers");
            $("#stores > .storeframe").toggle();
            $("#map_search_submit").toggle();
            return $("#stores > hr").toggle();
          } else if (ui.index === 1) {
            $("#tab-head span").text(store_locator_title);
            $("#stores > .storeframe").toggle();
            $("#map_search_submit").toggle();
            return $("#stores > hr").toggle();
          }
        });
        toggle_store_fields();
        $.getScript("/javascripts/vendor/jquery.metadata.js", function() {
          return $("#map").jMapping({
            default_point: {
              lat: lat,
              lng: lng
            },
            default_zoom_level: zoom,
            link_selector: ".map-link"
          });
        });
        $("#country").change(function() {
          return toggle_store_fields();
        });
        $("#map_search_submit").click(function() {
          var country_val, name_is_blank, state_is_blank;
          state_is_blank = $("#state").val().length === 0;
          name_is_blank = $("#name").val().length === 0;
          country_val = $("#country").val();
          if (country_val === "United States" && state_is_blank && $("#zip_code").val().length === 0 && name_is_blank) {
            alert("Please select state or zip code or search by name");
            return false;
          } else if (country_val === "United States" && $("#zip_code").val().length < 5 && state_is_blank && name_is_blank) {
            alert("Invalid zip code");
            return false;
          }
          $.ajax({
            url: "/index/update_map?" + $(this).parents("form").serialize(),
            success: function(html) {
              $("#map-side-bar").html(html);
              $("#map").jMapping("update");
              if (html.length < 20) {
                $("#map").data("jMapping").map.setZoom(4);
              }
              $(".info-box").show();
              $(".info-box h3").css("cursor", "pointer");
              if ($("#map").data("jMapping").map.zoom > 15) {
                return $("#map").data("jMapping").map.setZoom(15);
              }
            }
          });
          return false;
        });
        if ($("#country").val() !== "United States") {
          return $("#map_search_submit").trigger("click");
        }
      }).bind("afterMapping.jMapping", function(e, m) {
        return setTimeout("$('#map').data('jMapping').map.setZoom(4)", 1200);
      });
    }

    toggle_store_fields = function() {
      $("#zip_code").val("");
      $("#name").val("");
      $("#state").val("");
      if ($("#country").val() === "United States") {
        $("#map_search_submit").removeClass("without_us_or_uk");
        $(".us_only").show();
        $(".us_or_uk_only").show();
        $(".zipcode").addClass("zipcode_us");
        $(".zipcode").removeClass("postcode_uk");
        return $(".zipcode h3").text("Search by Zip Code:");
      } else if ($("#country").val() === "United Kingdom") {
        $("#map_search_submit").removeClass("without_us_or_uk");
        $(".us_only").hide();
        $(".us_or_uk_only").show();
        $(".zipcode").addClass("postcode_uk");
        $(".zipcode").removeClass("zipcode_us");
        return $(".zipcode h3").text("Search by Post Code:");
      } else {
        $("#map_search_submit").addClass("without_us_or_uk");
        $(".us_only").hide();
        return $(".us_or_uk_only").hide();
      }
    };

    return StoreLocator;

  })();

}).call(this);
