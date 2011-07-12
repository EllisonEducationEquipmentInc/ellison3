/* DO NOT MODIFY. This file was compiled Fri, 08 Jul 2011 23:20:03 GMT from
 * /home/mark/ellison3/app/coffeescripts/application.coffee
 */

(function() {
  var root;
  root = typeof exports !== "undefined" && exports !== null ? exports : this;
  if (!Array.prototype.indexOf) {
    Array.prototype.indexOf = function(elt) {
      var from, len;
      len = this.length >> 0;
      from = Number(arguments[1]) || 0;
      from = (from < 0 ? Math.ceil(from) : Math.floor(from));
      if (from < 0) {
        from += len;
      }
      while (from < len) {
        if (from in this && this[from] === elt) {
          return from;
        }
        from++;
      }
      return -1;
    };
  }
  root._gaq = root._gaq || [];
  root.button_label = root.button_label || "";
  root.number_only = function(e) {
    if (!(e.keyCode >= 96 && e.keyCode <= 105) && e.keyCode !== 46 && e.keyCode !== 8 && e.keyCode !== 9 && !String.fromCharCode(e.keyCode).match(/\d+/)) {
      return false;
    }
  };
  root.outlet = location.pathname.indexOf("/outlet") >= 0;
  root.current_system = root.current_system || "szus";
  root.sleep = function(milliseconds) {
    var i, start, _results;
    start = new Date().getTime();
    i = 0;
    _results = [];
    while (i < 1e7) {
      if ((new Date().getTime() - start) > milliseconds) {
        break;
      }
      _results.push(i++);
    }
    return _results;
  };
  root.initialize_lightboxes = function() {
    return $("a.lightbox").fancybox({
      transitionIn: "elastic",
      transitionOut: "elastic",
      speedIn: 500,
      speedOut: 200,
      overlayShow: true,
      titleShow: false,
      onComplete: function() {
        return setTimeout("$.fancybox.resize()", 100);
      }
    });
  };
  root.initialize_facets = function(accordion) {
    return $(".facets .head").click(function() {
      if (accordion) {
        $(".facets").find("ul").slideUp();
      }
      $(this).find("span").toggleClass("ui-icon-triangle-1-e");
      $(this).find("span").toggleClass("ui-icon-triangle-1-s");
      if (accordion) {
        $(this).next().slideToggle();
      } else {
        $(this).next().toggle();
      }
      return false;
    }).next().hide();
  };
  root.shadow_on = function() {
    $(".item-block").shadowOn({
      autoresize: false,
      resizetimer: 20,
      imageset: 1,
      imagepath: "/images/ui-plugins/shadowOn"
    });
    $(".item_images").shadowOn({
      autoresize: false,
      imageset: 1,
      imagepath: "/images/ui-plugins/shadowOn"
    });
    return $(".floating_survey").shadowOn({
      autoresize: false,
      imageset: 46,
      imagepath: "/images/ui-plugins/shadowOn"
    });
  };
  root.bind_hashchange = function() {
    return $(window).bind("hashchange", function(event) {
      var event_name, hash, outlet_param;
      hash = location.hash;
      if (location.pathname.indexOf("/catalog") >= 0 || outlet) {
        event_name = (outlet ? "Outlet" : "Catalog");
        outlet_param = (outlet ? "outlet=1&" : "");
        _gaq.push(["_trackEvent", event_name, "Search", $.param.fragment()]);
        return $.ajax({
          url: "/index/search?lang=" + $("html").attr("lang") + "&s=" + current_system + "&" + outlet_param + $.param.fragment(),
          beforeSend: function() {
            $("#product_catalog").css({
              opacity: 0.3
            });
            return $("#products_filter").css({
              opacity: 0.3
            });
          },
          complete: function() {
            $("#product_catalog").css({
              opacity: 1
            });
            return $("#products_filter").css({
              opacity: 1
            });
          }
        });
      }
    });
  };
  root.highlight_keyword = function() {
    var term;
    term = $.getUrlVar("q") || $.deparam.fragment()["q"];
    if (term === void 0 || term.length === 0) {
      return false;
    } else {
      $("span.highlight").each(function() {
        return $(this).after($(this).html()).remove();
      });
      $("div.highlightable :icontains(\"" + term + "\")").filter(function() {
        return this.children.length === 0;
      }).each(function() {
        var regexp;
        regexp = new RegExp(term, "gi");
        $(this).html($(this).html().replace(regexp, "<span class=\"highlight\">" + $(this).html().match(regexp)[0] + "</span>"));
        return $(this).find("span.highlight").fadeIn("slow");
      });
      return false;
    }
  };
  root.add_to_title = function(text) {
    var match;
    match = document.title.match(/^Catalog (- Search:([^|]+))?|/)[1];
    if (match === void 0) {
      return document.title = document.title.replace("Catalog ", "Catalog - Search: " + text + " ");
    } else {
      return document.title = document.title.replace(match, match + " - " + text + " ");
    }
  };
  root.remove_from_title = function(text) {
    return document.title = document.title.replace(new RegExp("( - )?" + text + "?"), "");
  };
  root.redirect_to_order = function(order_path) {
    return window.location.href = order_path;
  };
  root.er_number_only = function() {
    return $("input.er_product_quantity").keydown(number_only);
  };
  root.initialize_tables = function() {
    $("table:not('div#event_calendar table')").each(function() {
      $(this).addClass("ui-widget ui-widget-content ui-corner-all");
      return $(this).attr({
        cellspacing: "0",
        cellpadding: "0"
      });
    });
    return $("table thead:not('div#event_calendar table thead')").each(function() {
      return $(this).addClass("ui-state-hover");
    });
  };
  root.initialize_buttons = function() {
    $(function() {
      return $(".add_to_cart").button({
        icons: {
          primary: "ui-icon-plus"
        }
      }).click(function(e) {
        var qty;
        qty = ($(this).siblings("input.er_product_quantity").val() === void 0 ? "" : "&qty=" + $(this).siblings("input.er_product_quantity").val());
        $.ajax({
          url: "/carts/add_to_cart?id=" + this.id.replace("add_to_cart_", "") + qty
        });
        $(this).button({
          disabled: true
        });
        return _gaq.push(["_trackEvent", "Cart", "Add To Cart", $(this).attr("rel")]);
      });
    });
    $(function() {
      return $(".wishlist").button().click(function() {
        $.ajax({
          url: "/add_to_list?id=" + this.id.replace("add_to_list_", "")
        });
        return _gaq.push(["_trackEvent", "Lists", "Add To Default List", $(this).attr("rel")]);
      }).next().button({
        text: false,
        icons: {
          primary: "ui-icon-triangle-1-s"
        }
      }).click(function() {
        $(this).parent("p").next(".wishlist_loader").show();
        return $.ajax({
          url: "/users/get_lists?id=" + this.id.replace("add_to_list_", "") + "&item_num=" + $(this).attr("rel"),
          context: $(this).parent("p"),
          success: function(data) {
            $(this).next(".wishlist_loader").hide();
            if (data[0] !== "$") {
              return $(this).after(data);
            }
          }
        });
      }).parent().buttonset();
    });
    $(function() {
      return $(".jqui_button").button();
    });
    $(function() {
      return $(".jqui_save").button({
        icons: {
          primary: "ui-icon-disk"
        }
      });
    });
    $(function() {
      return $(".jqui_ok").button({
        icons: {
          primary: "ui-icon-check"
        }
      });
    });
    $(function() {
      return $(".jqui_cancel").button({
        icons: {
          primary: "ui-icon-closethick"
        }
      });
    });
    $(function() {
      return $(".jqui_new").button({
        icons: {
          primary: "ui-icon-plusthick"
        }
      });
    });
    $(function() {
      return $(".jqui_clone").button({
        icons: {
          primary: "ui-icon-newwin"
        }
      });
    });
    $(function() {
      return $(".jqui_trash").button({
        icons: {
          primary: "ui-icon-trash"
        }
      });
    });
    $(function() {
      return $(".jqui_back").button({
        icons: {
          primary: "ui-icon-triangle-1-w"
        }
      });
    });
    $(function() {
      return $(".jqui_search").button({
        icons: {
          primary: "ui-icon-search"
        }
      });
    });
    $(function() {
      return $(".jqui_account").button({
        icons: {
          primary: "ui-icon-person"
        }
      });
    });
    $(function() {
      return $(".jqui_admin").button({
        icons: {
          primary: "ui-icon-wrench"
        }
      });
    });
    $(function() {
      return $(".jqui_destroy_min").button({
        icons: {
          primary: "ui-icon-trash"
        },
        text: false
      });
    });
    $(function() {
      return $(".jqui_show_min").button({
        icons: {
          primary: "ui-icon-document"
        },
        text: false
      });
    });
    $(function() {
      return $(".jqui_edit_min").button({
        icons: {
          primary: "ui-icon-pencil"
        },
        text: false
      });
    });
    $(function() {
      return $(".jqui_cart_min").button({
        icons: {
          primary: "ui-icon-cart"
        },
        text: false
      });
    });
    $(function() {
      return $(".jqui_messages_min").button({
        icons: {
          primary: "ui-icon-mail-closed"
        },
        text: false
      });
    });
    $(function() {
      return $(".jqui_out_of_stock").button({
        icons: {
          primary: "ui-icon-alert"
        },
        disabled: true
      });
    });
    $(function() {
      return $(".jqui_clipboard").button({
        icons: {
          primary: "ui-icon-clipboard"
        }
      });
    });
    $(function() {
      return $(".jqui_show").button({
        icons: {
          primary: "ui-icon-document"
        }
      });
    });
    return $(function() {
      return $(".jqui_move_min").button({
        icons: {
          primary: "ui-icon-extlink"
        },
        text: false
      });
    });
  };
  root.order_comment = function() {
    return $("#order_comment").click(function() {
      $(this).find("span").toggleClass("ui-icon-triangle-1-s");
      $(this).find("span").toggleClass("ui-icon-triangle-1-e");
      $(this).next().toggle();
      return false;
    }).next().hide();
  };
  root.initialize_show_cart = function() {
    return $(".show_cart").click(function() {
      _gaq.push(["_trackEvent", "Cart", "Show Cart"]);
      show_cart();
      setTimeout("$.fancybox.resize()", 1600);
      return false;
    });
  };
  root.show_cart = function() {
    $.fancybox({
      padding: 10,
      autoScale: false,
      scrolling: "auto",
      speedIn: 500,
      speedOut: 200,
      href: "/cart",
      width: 860,
      autoDimensions: true,
      title: false,
      onComplete: function() {
        if ($("#fancybox-wrap:visible").length > 0) {
          $(".save_for_later").hide();
        }
        return setTimeout("$.fancybox.resize()", 100);
      }
    });
    setTimeout("$.fancybox.resize()", 900);
    return false;
  };
  root.add_fields = function(link, association, content) {
    var column_height, new_id, regexp;
    new_id = new Date().getTime();
    regexp = new RegExp("new_" + association, "g");
    $(link).before(content.replace(regexp, new_id));
    column_height = $(link).closest("li").height() + 100;
    return $(link).closest("li").css({
      height: column_height + "px"
    });
  };
  root.split = function(val) {
    return val.split(/,\s*/);
  };
  root.extractLast = function(term) {
    return split(term).pop();
  };
  root.sortable_tabs = function(id, obj) {
    $("#tabs").sortable({
      update: function(event, ui) {
        return $.ajax({
          url: "/admin/" + obj + "s/reorder_tabs?id=" + id + "&" + $("#tabs").sortable("serialize")
        });
      }
    });
    return $("#tabs").disableSelection();
  };
  root.fancyloader = function(text) {
    $.fancybox({
      hideOnOverlayClick: false,
      padding: 10,
      autoScale: true,
      speedIn: 500,
      speedOut: 200,
      showCloseButton: false,
      showNavArrows: false,
      enableEscapeButton: false,
      overlayOpacity: 0.7,
      width: 860,
      title: false,
      content: "<div style=\"text-align:center;width: 260px;\"><p>" + text + "</p><img src=\"/images/ui-objects/loader-ajax_bar.gif\" /></div>"
    });
    return setTimeout("$.fancybox.resize()", 1000);
  };
  root.doRound = function(x, places) {
    return Math.round(x * Math.pow(10, places)) / Math.pow(10, places);
  };
  root.update_net = function(field, currency, vat_rate) {
    return $("#product_msrp_" + currency).val(doRound(field.val() / ((vat_rate / 100) + 1), 2));
  };
  root.update_gross = function(field, currency, vat_rate) {
    return $("#msrp_" + currency + "_gross").val(doRound(field.val() * ((vat_rate / 100) + 1), 2));
  };
  root.check_items_checkboxes = function(element, model) {
    var i, item_nums, _results;
    console.log(element);
    if (model === void 0) {
      model = "product";
    }
    if (element.find("." + model + "_autocomplete").val() === void 0) {
      return false;
    }
    $(element).find(".admin_checkboxes [type=checkbox]").attr("checked", false);
    item_nums = element.find("." + model + "_autocomplete").val().split(/,\s*/);
    i = 0;
    _results = [];
    while (i < item_nums.length) {
      $(element).find(".admin_checkboxes [type=checkbox][value=" + item_nums[i] + "]").attr("checked", true);
      _results.push(i++);
    }
    return _results;
  };
  root.check_items_to_item_num_field = function(element, model) {
    var items, text_field;
    if (model === void 0) {
      model = "product";
    }
    text_field = $(element).parents("." + model + "s_helper").find("." + model + "_autocomplete");
    if (text_field.val() === void 0) {
      return false;
    }
    items = split(text_field.val());
    if ($(element).attr("checked")) {
      items.push(element.value);
    } else {
      items.splice(items.indexOf(element.value), 1);
    }
    if (items.indexOf("") >= 0) {
      items.splice(items.indexOf(""), 1);
    }
    return text_field.val(uniq(items).join(", "));
  };
  root.uniq = function(array) {
    var i;
    i = 0;
    while (i < array.length) {
      if (array.indexOf(array[i]) !== array.lastIndexOf(array[i])) {
        array.splice(array.lastIndexOf(array[i]), 1);
      }
      i++;
    }
    return array;
  };
  root.calculate_sale_price = function(price, discount, discount_type) {
    if (discount_type === "0") {
      return doRound(price - (0.01 * discount * price), 2);
    } else if (discount_type === "1") {
      if (price - discount > 0) {
        return price - discount;
      } else {
        return 0.0;
      }
    } else {
      if (discount_type === "2") {
        return discount;
      }
    }
  };
  root.megamenuHoverOver = function() {
    var meganav_hover, meganav_hover_bg, meganav_hover_border, panelOverhang, panelWidth, siteWidth, xCoord, xOrigin;
    siteWidth = 950;
    panelWidth = 0;
    xOrigin = 0;
    xCoord = 0;
    if ($("#nav_megamenu ul").position().left < 0) {
      xOrigin = Math.abs($("#nav_megamenu ul").position().left) - $(this).position().left;
    } else {
      xOrigin = -(Math.abs($("#nav_megamenu ul").position().left) + $(this).position().left);
    }
    if ($(this).find(".megapanel").hasClass("full-width")) {
      xCoord = xOrigin;
    } else {
      $(this).find(".megapanel ul[class*=\"wrap\"]").each(function() {
        panelWidth += $(this).width();
        return panelWidth += parseInt($(this).css("padding-left"), 10);
      });
      $(this).find(".megapanel").css({
        width: panelWidth + "px",
        "padding-right": "10px"
      });
      if ($(this).find(".megapanel").hasClass("reverse")) {
        xCoord = $(this).width() - panelWidth;
      }
      panelOverhang = (siteWidth + xOrigin) - (panelWidth + 10);
      if (panelOverhang > 0) {
        xCoord = xCoord -= 1;
      } else {
        xCoord = panelOverhang;
      }
    }
    $(this).find(".megapanel").css({
      left: xCoord + "px"
    });
    if (current_system === "szus") {
      meganav_hover_bg = "#e3dfd1";
      meganav_hover_border = "#d0c7a9";
    } else if (current_system === "eeus" || current_system === "eeuk") {
      meganav_hover_bg = "#e1e1e1";
    } else {
      meganav_hover_bg = "transparent";
    }
    $(this).css({
      "background-color": meganav_hover_bg
    });
    if (current_system === "szus") {
      $(this).css({
        border: "1px solid " + meganav_hover_border,
        "border-bottom": "0px"
      });
    }
    if (current_system === "szuk") {
      meganav_hover = "#ffffcc";
    }
    if (current_system === "erus") {
      meganav_hover = "#6382e0";
    }
    $(this).find("a.megalink").css({
      color: current_system === "szuk" || current_system === "erus" ? meganav_hover : void 0
    });
    return $(this).find(".megapanel").stop().slideDown(15, function() {
      if (current_system !== "szus") {
        return $(this).shadowOn(megapanel_shadow_options);
      }
    });
  };
  root.megamenuHoverOut = function() {
    var meganav_hover_bg, meganav_hoverout, meganav_hoverout_border;
    if (current_system === "szus") {
      meganav_hoverout_border = "#f7f7f5";
    } else {
      meganav_hover_bg = "transparent";
    }
    $(this).css({
      "background-color": "transparent"
    });
    $(this).css({
      "border-color": current_system === "szus" ? meganav_hoverout_border : void 0
    });
    if (current_system === "szuk") {
      meganav_hoverout = "#eeeeee";
    }
    if (current_system === "erus") {
      meganav_hoverout = "#eeeeee";
    }
    $(this).find("a.megalink").css({
      color: current_system === "szuk" || current_system === "erus" ? meganav_hoverout : void 0
    });
    return $(this).find(".megapanel").stop().slideUp(15, function() {
      return $(this).shadowOff();
    });
  };
  root.toggle_visual_asset_type = function(child_index) {
    $(".visual_asset_" + child_index + " .type_specific").hide();
    if ($("#landing_page_visual_assets_attributes_" + child_index + "_asset_type").length > 0) {
      $(".visual_asset_" + child_index + " ." + $("#landing_page_visual_assets_attributes_" + child_index + "_asset_type").val()).show();
    }
    if ($("#shared_content_visual_assets_attributes_" + child_index + "_asset_type").length > 0) {
      $(".visual_asset_" + child_index + " ." + $("#shared_content_visual_assets_attributes_" + child_index + "_asset_type").val()).show();
    }
    if ($("#tag_visual_assets_attributes_" + child_index + "_asset_type").length > 0) {
      return $(".visual_asset_" + child_index + " ." + $("#tag_visual_assets_attributes_" + child_index + "_asset_type").val()).show();
    }
  };
  root.toggle_child_visual_asset_type = function(child_index, value) {
    $(".visual_asset_child_" + child_index + " .type_specific").hide();
    return $(".visual_asset_child_" + child_index + " ." + value).show();
  };
  root.youtube_video_links = function() {
    return $(".fancyvideo").live("click", function() {
      $.fancybox({
        padding: 0,
        autoScale: false,
        transitionIn: "none",
        transitionOut: "none",
        title: this.title,
        width: 680,
        height: 495,
        href: this.href,
        type: "iframe"
      });
      return false;
    });
  };
  root.process_items_json = function(data, model) {
    var items;
    if (model === void 0) {
      model = "product";
    }
    items = [];
    $.each(data, function(key, val) {
      return items.push("<div class=\"" + model + "_helper_check_box_row " + val.tag_ids.join(" ") + " " + val.systems_enabled.join(" ") + "\"><input class=\"" + model + "_helper_check_box\" name=\"" + model + "_helper\" onchange=\"check_items_to_item_num_field(this,'" + model + "')\" type=\"checkbox\" value=\"" + val.item_num + "\"><img alt=\"" + val.item_num + "\" height=\"12\" onmouseout=\"$(this).css({'height': '12px', 'width': '12px', 'position': 'relative', 'z-index': 1})\" onmouseover=\"$(this).css({'height': '65px', 'width': '65px', 'position': 'absolute', 'z-index': 99})\" src=\"" + val.small_image + "\" width=\"12\" style=\"height: 12px; width: 12px; position: relative; z-index: 1; \">" + val.label + "<br /></div>");
    });
    return $("<div>", {
      "class": "admin_checkboxes ui-corner-all",
      html: items.join("")
    }).before("<a class=\"link_add-all\" href=\"#\" onclick=\"$(this).parent().find('[type=checkbox][checked=false]:visible').attr('checked', true).each(function (i) {check_items_to_item_num_field(this,'" + model + "')}); return false;\">add all visible</a> | <a href=\"#\" class=\"toggle_current_all_systems\" onclick=\"$(this).parent().find('." + model + "_helper_check_box_row:not(." + current_system + ")').toggle(); $(this).text( function(index, text){return text.indexOf('all') >= 0 ? 'show " + current_system + " only' : 'show all systems'}); return false;\">show " + current_system + " only</a>");
  };
  $(document).ajaxSend(function(e, xhr, options) {
    var token;
    token = $("meta[name='csrf-token']").attr("content");
    return xhr.setRequestHeader("X-CSRF-Token", token);
  });
  $.ajaxSetup({
    headers: {
      "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
    }
  });
  $(function() {
    return $(".wymeditor").wymeditor({
      stylesheet: "/stylesheets/wymeditor/styles.css",
      logoHtml: ""
    });
  });
  $(function() {
    return $(".datetimepicker").datetimepicker({
      dateFormat: "yy-mm-dd",
      changeMonth: true,
      changeYear: true
    });
  });
  $(function() {
    return $(".product_admin_thumbnail").bind("mouseover mouseout", function() {
      return $(this).toggleClass("to_delete");
    });
  });
  $(function() {
    return $(".thumbnail").bind("mouseover", function() {
      $(".thumbnail").removeClass("selected");
      return $(this).addClass("selected");
    });
  });
  $(document).ready(function() {
    var hoverconfig, options;
    bind_hashchange();
    initialize_facets();
    options = {
      zoomWidth: 350,
      zoomHeight: 370,
      xOffset: 32,
      yOffset: 0,
      position: "right",
      zoomType: "innerzoom",
      title: false,
      showEffect: "fadein",
      hideEffect: "fadeout"
    };
    $(".imagezoom").jqzoom(options);
    initialize_lightboxes();
    initialize_buttons();
    initialize_show_cart();
    $(function() {
      return $(".tab-block").tabs();
    });
    $(function() {
      return $(".accordion-block").accordion();
    });
    $("#nav_megamenu").find(".resize").each(function() {
      return $(this).css({
        width: function(index, value) {
          return parseFloat(value) - 20.0;
        }
      });
    });
    hoverconfig = {
      autoresize: false,
      sensitivity: 2,
      interval: 125,
      over: megamenuHoverOver,
      timeout: 500,
      out: megamenuHoverOut
    };
    $("#nav_megamenu li.megaitem").hoverIntent(hoverconfig);
    $(".boxgrid-narrow.captionfull, .boxgrid-wide.captionfull").live("mouseover mouseout", function(event) {
      if (event.type === "mouseover") {
        return $(".cover", this).stop().animate({
          top: "55px"
        }, {
          queue: false,
          duration: 160
        });
      } else {
        return $(".cover", this).stop().animate({
          top: "188px"
        }, {
          queue: false,
          duration: 160
        });
      }
    });
    initialize_tables();
    highlight_keyword();
    jQuery.validator.addMethod("phoneUS", function(phone_number, element) {
      phone_number = phone_number.replace(/\s+/g, "");
      return this.optional(element) || phone_number.length > 9 && phone_number.match(/^(1-?)?(\([2-9]\d{2}\)|[2-9]\d{2})-?[2-9]\d{2}-?\d{4}$/);
    }, "Please specify a valid US phone number");
    jQuery.validator.addMethod("zipUS", function(zip, element) {
      return this.optional(element) || zip.match(/^\d{5}(-\d{4})?$/);
    }, "Please specify a valid US zip code. Ex: 92660 or 92660-1234");
    jQuery.validator.addMethod("cvv", function(cvv, element) {
      return this.optional(element) || cvv.match(/^\d{3,4}$/);
    }, "Security Code is invalid");
    jQuery.validator.addMethod("greaterThanZero", function(value, element) {
      return this.optional(element) || (parseFloat(value) > 0);
    }, "Amount must be greater than zero");
    er_number_only();
    $(".tooltip_playvideo").CreateBubblePopup({
      position: "top",
      align: "center",
      distance: "50px",
      tail: {
        align: "middle",
        hidden: false
      },
      selectable: true,
      innerHtml: "<div class=\"tip_play-video\">click to play this video</div>",
      innerHtmlStyle: {
        color: "#333333",
        "text-align": "center"
      },
      themeName: "azure",
      themePath: "/images/ui-plugins/bubblepopup"
    });
    youtube_video_links();
    $("input.noautocomplete").doTimeout(2000, function() {
      return $(this).attr("autocomplete", "off");
    });
    $(".field_with_errors, .errorExplanation").each(function() {
      return $(this).addClass("ui-corner-all");
    });
    return shadow_on();
  });
  root.single_auto_complete_options = {
    source: function(request, response) {
      return $.ajax({
        url: "/products_autocomplete",
        dataType: "text json",
        data: {
          term: extractLast(request.term)
        },
        success: function(data) {
          return response(data);
        }
      });
    },
    search: function() {
      var term;
      term = extractLast(this.value);
      if (term.length < 2) {
        return false;
      }
    },
    focus: function() {
      return false;
    },
    select: function(event, ui) {
      this.value = split(ui.item.value).pop();
      return false;
    }
  };
  root.auto_complete_options = {
    source: function(request, response) {
      return $.ajax({
        url: "/products_autocomplete",
        dataType: "text json",
        data: {
          term: extractLast(request.term)
        },
        success: function(data) {
          return response(data);
        }
      });
    },
    search: function() {
      var term;
      term = extractLast(this.value);
      if (term.length < 2 || term.replace(/^All\s?/, "").length < 2) {
        return false;
      }
    },
    focus: function() {
      return false;
    },
    select: function(event, ui) {
      var i, item_nums, terms;
      terms = split(this.value);
      terms.pop();
      terms = terms.concat(split(ui.item.value), [""]);
      this.value = uniq(terms).join(", ");
      item_nums = split(ui.item.value);
      i = 0;
      while (i < item_nums.length) {
        $(this).parent().find(".admin_checkboxes [type=checkbox][value=" + item_nums[i] + "]").attr("checked", true);
        i++;
      }
      return false;
    }
  };
  $.extend({
    getUrlVars: function() {
      var hash, hashes, i, vars;
      vars = [];
      hashes = window.location.href.slice(window.location.href.indexOf("?") + 1).split("&");
      i = 0;
      while (i < hashes.length) {
        hash = hashes[i].split("=");
        vars.push(hash[0]);
        vars[hash[0]] = hash[1];
        i++;
      }
      return vars;
    },
    getUrlVar: function(name) {
      return $.getUrlVars()[name];
    }
  });
  $.expr[":"].icontains = function(obj, index, meta, stack) {
    return (obj.textContent || obj.innerText || jQuery(obj).text() || "").toLowerCase().indexOf(meta[3].toLowerCase()) >= 0;
  };
  root.megapanel_shadow_options = {
    autoresize: false,
    imageset: 6,
    imagepath: "/images/ui-plugins/shadowOn"
  };
  root.payment_validator_options = {
    errorClass: "invalid",
    rules: {
      "payment[first_name]": {
        required: true
      },
      "payment[last_name]": {
        required: true
      },
      "payment[card_name]": {
        required: true
      },
      "payment[full_card_number]": {
        required: true,
        creditcard: true
      },
      "payment[card_security_code]": {
        required: true,
        cvv: true
      },
      "payment[card_expiration_month]": {
        required: true
      },
      "payment[card_expiration_year]": {
        required: true
      }
    },
    submitHandler: function(form) {
      _gaq.push(["_trackEvent", "Cart", "Place Order"]);
      fancyloader("Your order is being processed. Thank you for your patience!");
      return $("#proceed_checkout").callRemote();
    },
    messages: {
      "payment[first_name]": {
        required: "Please provide your First Name."
      },
      "payment[last_name]": {
        required: "Please provide your Last Name."
      },
      "payment[card_name]": {
        required: "Please select a Credit Card Type."
      },
      "payment[full_card_number]": {
        required: "Please provide your Credit Card Number.",
        creditcard: "This is not a valid Credit Card Number."
      },
      "payment[card_security_code]": {
        required: "Please provide your Card's Security Code."
      },
      "payment[card_expiration_month]": {
        required: "In what Month does your card expire?"
      },
      "payment[card_expiration_year]": {
        required: "In what Year does your card expire?"
      }
    }
  };
}).call(this);
