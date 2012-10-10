(function() {

  document.StoreLocator = (function() {
    var toggle_store_fields;

    function StoreLocator(store_locator_title, lat, lng, zoom) {
      $(document).ready(function() {
        $(".tab-block").tabs();
        $(".tab-block").tabs("select", 1);
        $(".tab-block").bind("tabsselect", function(event, ui) {
          if (ui.index === 0) {
            return $("#tab-head span").text("Online Retailers");
          } else {
            if (ui.index === 1) {
              return $("#tab-head span").text(store_locator_title);
            }
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
          if ($("#country").val() === "United States" && $("#zip_code").val().length < 5) {
            alert("invalid zip code");
            return false;
          }
          if ($(".brands:checked").length < 1) {
            alert("please select at least one brand");
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
      if ($("#country").val() === "United States") {
        return $(".us_only").show();
      } else {
        return $(".us_only").hide();
      }
    };

    return StoreLocator;

  })();

}).call(this);
