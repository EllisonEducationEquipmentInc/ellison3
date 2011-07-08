root = exports ? this
unless Array::indexOf
  Array::indexOf = (elt) ->
    len = @length >> 0
    from = Number(arguments[1]) or 0
    from = (if (from < 0) then Math.ceil(from) else Math.floor(from))
    from += len  if from < 0
    while from < len
      return from  if from of this and this[from] == elt
      from++
    -1
    
root._gaq = root._gaq or []
root.button_label = root.button_label or ""
root.number_only = (e) -> return false if !(e.keyCode >= 96 && e.keyCode <= 105) && e.keyCode != 46 && e.keyCode != 8 && e.keyCode != 9 && !String.fromCharCode(e.keyCode).match(/\d+/)
root.outlet = location.pathname.indexOf("/outlet") >= 0
root.current_system = root.current_system or "szus"

root.sleep = (milliseconds) ->
  start = new Date().getTime()
  i = 0
  
  while i < 1e7
    break  if (new Date().getTime() - start) > milliseconds
    i++
    
root.initialize_lightboxes = ->
  $("a.lightbox").fancybox 
    transitionIn: "elastic"
    transitionOut: "elastic"
    speedIn: 500
    speedOut: 200
    overlayShow: true
    titleShow: false
    onComplete: ->
      setTimeout "$.fancybox.resize()", 100
      
root.initialize_facets = (accordion) ->
  $(".facets .head").click(->
    $(".facets").find("ul").slideUp()  if accordion
    $(this).find("span").toggleClass "ui-icon-triangle-1-e"
    $(this).find("span").toggleClass "ui-icon-triangle-1-s"
    (if accordion then $(this).next().slideToggle() else $(this).next().toggle())
    false
  ).next().hide()
  
root.shadow_on = ->
  $(".item-block").shadowOn 
    autoresize: false
    resizetimer: 20
    imageset: 1
    imagepath: "/images/ui-plugins/shadowOn"
  
  $(".item_images").shadowOn 
    autoresize: false
    imageset: 1
    imagepath: "/images/ui-plugins/shadowOn"
  
  $(".floating_survey").shadowOn 
    autoresize: false
    imageset: 46
    imagepath: "/images/ui-plugins/shadowOn"
    
root.bind_hashchange = ->
  $(window).bind "hashchange", (event) ->
    hash = location.hash
    if location.pathname.indexOf("/catalog") >= 0 or outlet
      event_name = (if outlet then "Outlet" else "Catalog")
      outlet_param = (if outlet then "outlet=1&" else "")
      _gaq.push [ "_trackEvent", event_name, "Search", $.param.fragment() ]
      $.ajax 
        url: "/index/search?lang=" + $("html").attr("lang") + "&s=" + current_system + "&" + outlet_param + $.param.fragment()
        beforeSend: ->
          $("#product_catalog").css opacity: 0.3
          $("#products_filter").css opacity: 0.3
        
        complete: ->
          $("#product_catalog").css opacity: 1
          $("#products_filter").css opacity: 1
          
root.highlight_keyword = ->
  term = $.getUrlVar("q") or $.deparam.fragment()["q"]
  if term == undefined or term.length == 0
    false
  else
    $("span.highlight").each ->
      $(this).after($(this).html()).remove()
    
    $("div.highlightable :icontains(\"" + term + "\")").filter(->
      @children.length == 0
    ).each ->
      regexp = new RegExp(term, "gi")
      $(this).html $(this).html().replace(regexp, "<span class=\"highlight\">" + $(this).html().match(regexp)[0] + "</span>")
      $(this).find("span.highlight").fadeIn "slow"
    
    false
    
root.add_to_title = (text) ->
  match = document.title.match(/^Catalog (- Search:([^|]+))?|/)[1]
  if match == undefined
    document.title = document.title.replace("Catalog ", "Catalog - Search: " + text + " ")
  else
    document.title = document.title.replace(match, match + " - " + text + " ")
    
root.remove_from_title = (text) ->
  document.title = document.title.replace(new RegExp("( - )?" + text + "?"), "")
  
root.redirect_to_order = (order_path) ->
  window.location.href = order_path
  
root.er_number_only = ->
  $("input.er_product_quantity").keydown number_only
  
root.initialize_tables = ->
  $("table:not('div#event_calendar table')").each ->
    $(this).addClass "ui-widget ui-widget-content ui-corner-all"
    $(this).attr 
      cellspacing: "0"
      cellpadding: "0"
  
  $("table thead:not('div#event_calendar table thead')").each ->
    $(this).addClass "ui-state-hover"
    
root.initialize_buttons = ->
  $ ->
    $(".add_to_cart").button(icons: primary: "ui-icon-plus").click (e) ->
      qty = (if $(this).siblings("input.er_product_quantity").val() == undefined then "" else "&qty=" + $(this).siblings("input.er_product_quantity").val())
      $.ajax url: "/carts/add_to_cart?id=" + @id.replace("add_to_cart_", "") + qty
      $(this).button disabled: true
      _gaq.push [ "_trackEvent", "Cart", "Add To Cart", $(this).attr("rel") ]
  
  $ ->
    $(".wishlist").button().click(->
      $.ajax url: "/add_to_list?id=" + @id.replace("add_to_list_", "")
      _gaq.push [ "_trackEvent", "Lists", "Add To Default List", $(this).attr("rel") ]
    ).next().button(
      text: false
      icons: primary: "ui-icon-triangle-1-s"
    ).click(->
      $(this).parent("p").next(".wishlist_loader").show()
      $.ajax 
        url: "/users/get_lists?id=" + @id.replace("add_to_list_", "") + "&item_num=" + $(this).attr("rel")
        context: $(this).parent("p")
        success: (data) ->
          $(this).next(".wishlist_loader").hide()
          $(this).after data  unless data[0] == "$"
    ).parent().buttonset()
  
  $ ->
    $(".jqui_button").button()
  
  $ ->
    $(".jqui_save").button icons: primary: "ui-icon-disk"
  
  $ ->
    $(".jqui_ok").button icons: primary: "ui-icon-check"
  
  $ ->
    $(".jqui_cancel").button icons: primary: "ui-icon-closethick"
  
  $ ->
    $(".jqui_new").button icons: primary: "ui-icon-plusthick"
  
  $ ->
    $(".jqui_clone").button icons: primary: "ui-icon-newwin"
  
  $ ->
    $(".jqui_trash").button icons: primary: "ui-icon-trash"
  
  $ ->
    $(".jqui_back").button icons: primary: "ui-icon-triangle-1-w"
  
  $ ->
    $(".jqui_search").button icons: primary: "ui-icon-search"
  
  $ ->
    $(".jqui_account").button icons: primary: "ui-icon-person"
  
  $ ->
    $(".jqui_admin").button icons: primary: "ui-icon-wrench"
  
  $ ->
    $(".jqui_destroy_min").button 
      icons: 
        primary: "ui-icon-trash"
      text: false
  
  $ ->
    $(".jqui_show_min").button 
      icons: 
        primary: "ui-icon-document"
      text: false
  
  $ ->
    $(".jqui_edit_min").button 
      icons: 
        primary: "ui-icon-pencil"
      text: false
  
  $ ->
    $(".jqui_cart_min").button 
      icons: 
        primary: "ui-icon-cart"
      text: false
  
  $ ->
    $(".jqui_messages_min").button 
      icons: 
        primary: "ui-icon-mail-closed"
      text: false
  
  $ ->
    $(".jqui_out_of_stock").button 
      icons: 
        primary: "ui-icon-alert"
      disabled: true
  
  $ ->
    $(".jqui_clipboard").button icons: primary: "ui-icon-clipboard"
  
  $ ->
    $(".jqui_show").button icons: primary: "ui-icon-document"
  
  $ ->
    $(".jqui_move_min").button 
      icons: primary: "ui-icon-extlink"
      text: false
      
root.order_comment = ->
  $("#order_comment").click(->
    $(this).find("span").toggleClass "ui-icon-triangle-1-s"
    $(this).find("span").toggleClass "ui-icon-triangle-1-e"
    $(this).next().toggle()
    false
  ).next().hide()
  
root.initialize_show_cart = ->
  $(".show_cart").click ->
    _gaq.push [ "_trackEvent", "Cart", "Show Cart" ]
    show_cart()
    setTimeout "$.fancybox.resize()", 1600
    false
    
root.show_cart = ->
  $.fancybox 
    padding: 10
    autoScale: false
    scrolling: "auto"
    speedIn: 500
    speedOut: 200
    href: "/cart"
    width: 860
    autoDimensions: true
    title: false
    onComplete: ->
      $(".save_for_later").hide()  if $("#fancybox-wrap:visible").length > 0
      setTimeout "$.fancybox.resize()", 100
  
  setTimeout "$.fancybox.resize()", 900
  false
  
root.add_fields = (link, association, content) ->
  new_id = new Date().getTime()
  regexp = new RegExp("new_" + association, "g")
  $(link).before content.replace(regexp, new_id)
  column_height = $(link).closest("li").height() + 100
  $(link).closest("li").css height: (column_height) + "px"
  
root.split = (val) ->
  val.split /,\s*/
  
root.extractLast = (term) ->
  split(term).pop()
  
root.sortable_tabs = (id, obj) ->
  $("#tabs").sortable update: (event, ui) ->
    $.ajax url: "/admin/" + obj + "s/reorder_tabs?id=" + id + "&" + $("#tabs").sortable("serialize")
  
  $("#tabs").disableSelection()
  
root.fancyloader = (text) ->
  $.fancybox 
    hideOnOverlayClick: false
    padding: 10
    autoScale: true
    speedIn: 500
    speedOut: 200
    showCloseButton: false
    showNavArrows: false
    enableEscapeButton: false
    overlayOpacity: 0.7
    width: 860
    title: false
    content: "<div style=\"text-align:center;width: 260px;\"><p>" + text + "</p><img src=\"/images/ui-objects/loader-ajax_bar.gif\" /></div>"
  
  setTimeout "$.fancybox.resize()", 1000
  
root.doRound = (x, places) ->
  Math.round(x * Math.pow(10, places)) / Math.pow(10, places)
  
root.update_net = (field, currency, vat_rate) ->
  $("#product_msrp_" + currency).val doRound(field.val() / ((vat_rate / 100) + 1), 2)
  
root.update_gross = (field, currency, vat_rate) ->
  $("#msrp_" + currency + "_gross").val doRound(field.val() * ((vat_rate / 100) + 1), 2)
  
root.check_items_checkboxes = (element, model) ->
  console.log element
  model = "product"  if model == undefined
  return false  if element.find("." + model + "_autocomplete").val() == undefined
  $(element).find(".admin_checkboxes [type=checkbox]").attr "checked", false
  item_nums = element.find("." + model + "_autocomplete").val().split(/,\s*/)
  i = 0
  
  while i < item_nums.length
    $(element).find(".admin_checkboxes [type=checkbox][value=" + item_nums[i] + "]").attr "checked", true
    i++
    
root.check_items_to_item_num_field = (element, model) ->
  model = "product"  if model == undefined
  text_field = $(element).parents("." + model + "s_helper").find("." + model + "_autocomplete")
  return false  if text_field.val() == undefined
  items = split(text_field.val())
  if $(element).attr("checked")
    items.push element.value
  else
    items.splice items.indexOf(element.value), 1
  items.splice items.indexOf(""), 1  if items.indexOf("") >= 0
  text_field.val uniq(items).join(", ")
  
root.uniq = (array) ->
  i = 0
  
  while i < array.length
    array.splice array.lastIndexOf(array[i]), 1  unless array.indexOf(array[i]) == array.lastIndexOf(array[i])
    i++
  array
  
root.calculate_sale_price = (price, discount, discount_type) ->
  if discount_type == "0"
    doRound price - (0.01 * discount * price), 2
  else if discount_type == "1"
    (if price - discount > 0 then price - discount else 0.0)
  else discount  if discount_type == "2"
  
root.megamenuHoverOver = ->
  siteWidth = 950
  panelWidth = 0
  xOrigin = 0
  xCoord = 0
  
  if $("#nav_megamenu ul").position().left < 0
    xOrigin = Math.abs($("#nav_megamenu ul").position().left) - $(this).position().left
  else
    xOrigin = -(Math.abs($("#nav_megamenu ul").position().left) + $(this).position().left)
  if $(this).find(".megapanel").hasClass("full-width")
    xCoord = xOrigin
  else
    $(this).find(".megapanel ul[class*=\"wrap\"]").each ->
      panelWidth += $(this).width()
      panelWidth += parseInt($(this).css("padding-left"), 10)
    
    $(this).find(".megapanel").css 
      width: (panelWidth) + "px"
      "padding-right": "10px"
    
    xCoord = $(this).width() - panelWidth  if $(this).find(".megapanel").hasClass("reverse")
    panelOverhang = (siteWidth + xOrigin) - (panelWidth + 10)
    if panelOverhang > 0
      xCoord = xCoord -= 1
    else
      xCoord = panelOverhang
  $(this).find(".megapanel").css left: (xCoord) + "px"
  if current_system == "szus"
    meganav_hover_bg = "#e3dfd1"
    meganav_hover_border = "#d0c7a9"
  else if current_system == "eeus" or current_system == "eeuk"
    meganav_hover_bg = "#e1e1e1"
  else
    meganav_hover_bg = "transparent"
  $(this).css "background-color": meganav_hover_bg
  if current_system == "szus"
    $(this).css 
      border: "1px solid " + meganav_hover_border
      "border-bottom": "0px"
  meganav_hover = "#ffffcc"  if current_system == "szuk"
  meganav_hover = "#6382e0"  if current_system == "erus"
  $(this).find("a.megalink").css color: meganav_hover  if current_system == "szuk" or current_system == "erus"
  $(this).find(".megapanel").stop().slideDown 15, ->
    $(this).shadowOn megapanel_shadow_options  unless current_system == "szus"
    
root.megamenuHoverOut = ->
  if current_system == "szus"
    meganav_hoverout_border = "#f7f7f5"
  else
    meganav_hover_bg = "transparent"
  $(this).css "background-color": "transparent"
  $(this).css "border-color": meganav_hoverout_border  if current_system == "szus"
  meganav_hoverout = "#eeeeee"  if current_system == "szuk"
  meganav_hoverout = "#eeeeee"  if current_system == "erus"
  $(this).find("a.megalink").css color: meganav_hoverout  if current_system == "szuk" or current_system == "erus"
  $(this).find(".megapanel").stop().slideUp 15, ->
    $(this).shadowOff()
    
root.toggle_visual_asset_type = (child_index) ->
  $(".visual_asset_" + child_index + " .type_specific").hide()
  $(".visual_asset_" + child_index + " ." + $("#landing_page_visual_assets_attributes_" + child_index + "_asset_type").val()).show()  if $("#landing_page_visual_assets_attributes_" + child_index + "_asset_type").length > 0
  $(".visual_asset_" + child_index + " ." + $("#shared_content_visual_assets_attributes_" + child_index + "_asset_type").val()).show()  if $("#shared_content_visual_assets_attributes_" + child_index + "_asset_type").length > 0
  $(".visual_asset_" + child_index + " ." + $("#tag_visual_assets_attributes_" + child_index + "_asset_type").val()).show()  if $("#tag_visual_assets_attributes_" + child_index + "_asset_type").length > 0
  
root.toggle_child_visual_asset_type = (child_index, value) ->
  $(".visual_asset_child_" + child_index + " .type_specific").hide()
  $(".visual_asset_child_" + child_index + " ." + value).show()
  
root.youtube_video_links = ->
  $(".fancyvideo").live "click", ->
    $.fancybox 
      padding: 0
      autoScale: false
      transitionIn: "none"
      transitionOut: "none"
      title: @title
      width: 680
      height: 495
      href: @href
      type: "iframe"
    
    false
    
root.process_items_json = (data, model) ->
  model = "product"  if model == undefined
  items = []
  $.each data, (key, val) ->
    items.push "<div class=\"" + model + "_helper_check_box_row " + val.tag_ids.join(" ") + " " + val.systems_enabled.join(" ") + "\"><input class=\"" + model + "_helper_check_box\" name=\"" + model + "_helper\" onchange=\"check_items_to_item_num_field(this,'" + model + "')\" type=\"checkbox\" value=\"" + val.item_num + "\"><img alt=\"" + val.item_num + "\" height=\"12\" onmouseout=\"$(this).css({'height': '12px', 'width': '12px', 'position': 'relative', 'z-index': 1})\" onmouseover=\"$(this).css({'height': '65px', 'width': '65px', 'position': 'absolute', 'z-index': 99})\" src=\"" + val.small_image + "\" width=\"12\" style=\"height: 12px; width: 12px; position: relative; z-index: 1; \">" + val.label + "<br /></div>"
  
  $("<div>", 
    class: "admin_checkboxes ui-corner-all"
    html: items.join("")
  ).before "<a class=\"link_add-all\" href=\"#\" onclick=\"$(this).parent().find('[type=checkbox][checked=false]:visible').attr('checked', true).each(function (i) {check_items_to_item_num_field(this,'" + model + "')}); return false;\">add all visible</a> | <a href=\"#\" class=\"toggle_current_all_systems\" onclick=\"$(this).parent().find('." + model + "_helper_check_box_row:not(." + current_system + ")').toggle(); $(this).text( function(index, text){return text.indexOf('all') >= 0 ? 'show " + current_system + " only' : 'show all systems'}); return false;\">show " + current_system + " only</a>"
    
$(document).ajaxSend (e, xhr, options) ->
  token = $("meta[name='csrf-token']").attr("content")
  xhr.setRequestHeader "X-CSRF-Token", token

$.ajaxSetup headers: "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")

$ ->
  $(".wymeditor").wymeditor 
    stylesheet: "/stylesheets/wymeditor/styles.css"
    logoHtml: ""

$ ->
  $(".datetimepicker").datetimepicker 
    dateFormat: "yy-mm-dd"
    changeMonth: true
    changeYear: true

$ ->
  $(".product_admin_thumbnail").bind "mouseover mouseout", ->
    $(this).toggleClass "to_delete"

$ ->
  $(".thumbnail").bind "mouseover", ->
    $(".thumbnail").removeClass "selected"
    $(this).addClass "selected"

$(document).ready ->
  bind_hashchange()
  initialize_facets()
  options = 
    zoomWidth: 350
    zoomHeight: 370
    xOffset: 32
    yOffset: 0
    position: "right"
    zoomType: "innerzoom"
    title: false
    showEffect: "fadein"
    hideEffect: "fadeout"
  
  $(".imagezoom").jqzoom options
  initialize_lightboxes()
  initialize_buttons()
  initialize_show_cart()
  $ ->
    $(".tab-block").tabs()
  
  $ ->
    $(".accordion-block").accordion()
  
  $("#nav_megamenu").find(".resize").each ->
    $(this).css width: (index, value) ->
      parseFloat(value) - 20.0
  
  hoverconfig = 
    autoresize: false
    sensitivity: 2
    interval: 125
    over: megamenuHoverOver
    timeout: 500
    out: megamenuHoverOut
  
  $("#nav_megamenu li.megaitem").hoverIntent hoverconfig
  $(".boxgrid-narrow.captionfull, .boxgrid-wide.captionfull").live "mouseover mouseout", (event) ->
    if event.type == "mouseover"
      $(".cover", this).stop().animate top: "55px", 
        queue: false
        duration: 160
    else
      $(".cover", this).stop().animate top: "188px", 
        queue: false
        duration: 160
  
  initialize_tables()
  highlight_keyword()
  jQuery.validator.addMethod "phoneUS", (phone_number, element) ->
    phone_number = phone_number.replace(/\s+/g, "")
    @optional(element) or phone_number.length > 9 and phone_number.match(/^(1-?)?(\([2-9]\d{2}\)|[2-9]\d{2})-?[2-9]\d{2}-?\d{4}$/)
  , "Please specify a valid US phone number"
  jQuery.validator.addMethod "zipUS", (zip, element) ->
    @optional(element) or zip.match(/^\d{5}(-\d{4})?$/)
  , "Please specify a valid US zip code. Ex: 92660 or 92660-1234"
  jQuery.validator.addMethod "cvv", (cvv, element) ->
    @optional(element) or cvv.match(/^\d{3,4}$/)
  , "Security Code is invalid"
  jQuery.validator.addMethod "greaterThanZero", (value, element) ->
    @optional(element) or (parseFloat(value) > 0)
  , "Amount must be greater than zero"
  er_number_only()
  $(".tooltip_playvideo").CreateBubblePopup 
    position: "top"
    align: "center"
    distance: "50px"
    tail: 
      align: "middle"
      hidden: false
    
    selectable: true
    innerHtml: "<div class=\"tip_play-video\">click to play this video</div>"
    innerHtmlStyle: 
      color: "#333333"
      "text-align": "center"
    
    themeName: "azure"
    themePath: "/images/ui-plugins/bubblepopup"
  
  youtube_video_links()
  $("input.noautocomplete").doTimeout 2000, ->
    $(this).attr "autocomplete", "off"
  
  $(".field_with_errors, .errorExplanation").each ->
    $(this).addClass "ui-corner-all"
  
  shadow_on()

root.single_auto_complete_options = 
  source: (request, response) ->
    $.ajax 
      url: "/products_autocomplete"
      dataType: "text json"
      data: term: extractLast(request.term)
      success: (data) ->
        response data
  
  search: ->
    term = extractLast(@value)
    false  if term.length < 2
  
  focus: ->
    false
  
  select: (event, ui) ->
    @value = split(ui.item.value).pop()
    false

root.auto_complete_options = 
  source: (request, response) ->
    $.ajax 
      url: "/products_autocomplete"
      dataType: "text json"
      data: term: extractLast(request.term)
      success: (data) ->
        response data
  
  search: ->
    term = extractLast(@value)
    false  if term.length < 2 or term.replace(/^All\s?/, "").length < 2
  
  focus: ->
    false
  
  select: (event, ui) ->
    terms = split(@value)
    terms.pop()
    terms = terms.concat(split(ui.item.value), [ "" ])
    @value = uniq(terms).join(", ")
    item_nums = split(ui.item.value)
    i = 0
    
    while i < item_nums.length
      $(this).parent().find(".admin_checkboxes [type=checkbox][value=" + item_nums[i] + "]").attr "checked", true
      i++
    false

$.extend 
  getUrlVars: ->
    vars = []
    hashes = window.location.href.slice(window.location.href.indexOf("?") + 1).split("&")
    i = 0
    
    while i < hashes.length
      hash = hashes[i].split("=")
      vars.push hash[0]
      vars[hash[0]] = hash[1]
      i++
    vars
  
  getUrlVar: (name) ->
    $.getUrlVars()[name]

$.expr[":"].icontains = (obj, index, meta, stack) ->
  (obj.textContent or obj.innerText or jQuery(obj).text() or "").toLowerCase().indexOf(meta[3].toLowerCase()) >= 0

root.megapanel_shadow_options = 
  autoresize: false
  imageset: 6
  imagepath: "/images/ui-plugins/shadowOn"

root.payment_validator_options = 
  errorClass: "invalid"
  rules: 
    "payment[first_name]": 
      required: true
    "payment[last_name]": 
      required: true
    "payment[card_name]": 
      required: true
    "payment[full_card_number]": 
      required: true
      creditcard: true
    
    "payment[card_security_code]": 
      required: true
      cvv: true
    
    "payment[card_expiration_month]": 
      required: true
    "payment[card_expiration_year]": 
      required: true
  
  submitHandler: (form) ->
    _gaq.push [ "_trackEvent", "Cart", "Place Order" ]
    fancyloader "Your order is being processed. Thank you for your patience!"
    $("#proceed_checkout").callRemote()
  
  messages: 
    "payment[first_name]": 
      required: "Please provide your First Name."
    "payment[last_name]": 
      required: "Please provide your Last Name."
    "payment[card_name]": 
      required: "Please select a Credit Card Type."
    "payment[full_card_number]": 
      required: "Please provide your Credit Card Number."
      creditcard: "This is not a valid Credit Card Number."
    
    "payment[card_security_code]": 
      required: "Please provide your Card's Security Code."
    "payment[card_expiration_month]": 
      required: "In what Month does your card expire?"
    "payment[card_expiration_year]": 
      required: "In what Year does your card expire?"