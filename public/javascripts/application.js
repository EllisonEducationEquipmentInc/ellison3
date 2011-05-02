// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
if (!Array.prototype.indexOf)
{
  Array.prototype.indexOf = function(elt /*, from*/)
  {
    var len = this.length >>> 0;

    var from = Number(arguments[1]) || 0;
    from = (from < 0)
         ? Math.ceil(from)
         : Math.floor(from);
    if (from < 0)
      from += len;

    for (; from < len; from++)
    {
      if (from in this &&
          this[from] === elt)
        return from;
    }
    return -1;
  };
}
function sleep(milliseconds) {
  var start = new Date().getTime();
  for (var i = 0; i < 1e7; i++) {
    if ((new Date().getTime() - start) > milliseconds){
      break;
    }
  }
}
var _gaq = _gaq || [];
var button_label = button_label || '';
var number_only = function(e){if (!(e.keyCode >= 96 && e.keyCode <= 105) && e.keyCode != 46 && e.keyCode != 8 && e.keyCode != 9 && !String.fromCharCode(e.keyCode).match(/\d+/)) return false}
var outlet = location.pathname.indexOf("/outlet") >= 0;
var current_system = current_system || "szus";

$(document).ajaxSend(function(e, xhr, options) {
  var token = $("meta[name='csrf-token']").attr("content");
  xhr.setRequestHeader("X-CSRF-Token", token);
});
$.ajaxSetup({
  headers: {
    "X-CSRF-Token": $("meta[name='csrf-token']").attr('content')
  }
});
$(function() {
  $(".wymeditor").wymeditor({
    stylesheet: '/stylesheets/wymeditor/styles.css',
    logoHtml: ''
  });
});

$(function (){  
    $('.datetimepicker').datetimepicker({
					dateFormat: 'yy-mm-dd',
					changeMonth: true,
					changeYear: true
				});  
});

$(function() {
		$(".product_admin_thumbnail").bind('mouseover mouseout', function() { 
			$(this).toggleClass('to_delete');
		});
});

$(function() {
		$(".thumbnail").bind('mouseover', function() {
			$(".thumbnail").removeClass('selected');
			$(this).addClass('selected');
		});
});

// lightboxes
function initialize_lightboxes(){
	$("a.lightbox").fancybox({
			'transitionIn' : 'elastic',
			'transitionOut'	:	'elastic',
			'speedIn'	:	500, 
			'speedOut' :	200, 
			'overlayShow'	:	true,
			'titleShow': false,
			'onComplete' : function(){setTimeout("$.fancybox.resize()", 100)}
		});
}

// catalog facet filter collapsible menus
function initialize_facets(accordion) {
	$('.facets .head').click(function() {
	    if (accordion) $('.facets').find('ul').slideUp();
			$(this).find('span').toggleClass('ui-icon-triangle-1-e')
			$(this).find('span').toggleClass('ui-icon-triangle-1-s')
			accordion ? $(this).next().slideToggle() : $(this).next().toggle()
			return false;
		}).next().hide();
}

function shadow_on() {
	// shadowOn
	$(".item-block").shadowOn({autoresize: false, resizetimer: 20, imageset: 1, imagepath: "/images/ui-plugins/shadowOn" });  // drop shadow for item blocks on catalog pages
	$(".item_images").shadowOn({autoresize: false, imageset: 1, imagepath: "/images/ui-plugins/shadowOn" });  // drop shadow for item images on item detail pages
	$(".floating_survey").shadowOn({autoresize: false, imageset: 46, imagepath: "/images/ui-plugins/shadowOn" });  // drop shadow for item images on item detail pages
}

function bind_hashchange () {
	$(window).bind( 'hashchange', function(event){
	  var hash = location.hash;
		if (location.pathname.indexOf("/catalog") >= 0 || outlet) {
			var event_name = outlet ? "Outlet" : 'Catalog'
			var outlet_param = outlet ? "outlet=1&" : ''
			_gaq.push(['_trackEvent', event_name, 'Search', $.param.fragment()]);
			$.ajax({url:"/index/search?lang="+$('html').attr('lang')+'&'+outlet_param+$.param.fragment(), beforeSend: function(){$("#product_catalog").css({opacity: 0.3});$("#products_filter").css({opacity: 0.3})}, complete: function(){$("#product_catalog").css({opacity: 1});$("#products_filter").css({opacity: 1})}});
		}
	});
}

function highlight_keyword () {
	var term = $.getUrlVar('q') || $.deparam.fragment()['q'];
	if (term == undefined || term.length == 0) {
		return false;
	} else {
		$('span.highlight').each(function(){
			$(this).after($(this).html()).remove();
		});
		$('div.highlightable :icontains("'+term+'")').filter(function() {return this.children.length == 0}).each(function(){
			var regexp = new RegExp(term,'gi')
			$(this).html($(this).html().replace(regexp, '<span class="highlight">'+$(this).html().match(regexp)[0]+'</span>'));
			$(this).find('span.highlight').fadeIn("slow");
		});
		return false;
	}
}

function add_to_title (text) {
	match = document.title.match(/^Catalog (- Search:([^|]+))?|/)[1];
	if (match == undefined) {
		document.title = document.title.replace("Catalog ", "Catalog - Search: "+text+' ')
	} else {
		document.title = document.title.replace(match, match+' - '+text+' ');
	}
}

function remove_from_title (text) {
	document.title = document.title.replace(new RegExp("( - )?"+text+"?"), '');
}

function redirect_to_order (order_path) {
	window.location.href = order_path
}

function er_number_only() {
	$('input.er_product_quantity').keydown(number_only);
}

$(document).ready(function(){

	bind_hashchange ();
	
	initialize_facets();
	
	// image zoom
	var options = {
	    zoomWidth: 300,
	    zoomHeight: 300,
      xCoord: 10,
      yOffset: 0,
      position: "right",
			zoomType: "reverse"
		};
	$('.imagezoom').jqzoom(options);
	
	initialize_lightboxes();
	initialize_buttons();
	initialize_show_cart();
	
	$(function() {
		$(".tab-block").tabs();
	});
	$(function() {
		$(".accordion-block").accordion();
	});
		
	// mega menu
	$("#nav_megamenu").find('.resize').each(function(){
	  $(this).css({
      width: function(index, value) {
        return parseFloat(value) - 20.0;
      }
    });
	});
  var hoverconfig = { // hover intent custom configurations
		autoresize: false,
    sensitivity: 2, // number = sensitivity threshold (must be 1 or higher)
    interval: 125, // number = milliseconds for onMouseOver polling interval
    over: megamenuHoverOver, // function = onMouseOver callback (REQUIRED)
    timeout: 500, // number = milliseconds delay before onMouseOut
    out: megamenuHoverOut // function = onMouseOut callback (REQUIRED)
  };
  $("#nav_megamenu li.megaitem").hoverIntent(hoverconfig); // trigger hover intent with custom configurations	

  // billboard visual assets
  $('.boxgrid-narrow.captionfull, .boxgrid-wide.captionfull').live('mouseover mouseout', function(event) {
    if (event.type == 'mouseover') {
      $(".cover", this).stop().animate({top:'55px'},{queue:false,duration:160});
    } else {
      $(".cover", this).stop().animate({top:'188px'},{queue:false,duration:160});
    }
  });

  // jqueryui tables
  $("table:not('div#event_calendar table')").each(function() {
    $(this).addClass("ui-widget ui-widget-content ui-corner-all");
  });
  $("table thead:not('div#event_calendar table thead')").each(function() {
    $(this).addClass("ui-state-hover");
  });

	highlight_keyword();
	
	jQuery.validator.addMethod("phoneUS", function(phone_number, element) {
	    phone_number = phone_number.replace(/\s+/g, ""); 
		return this.optional(element) || phone_number.length > 9 &&
			phone_number.match(/^(1-?)?(\([2-9]\d{2}\)|[2-9]\d{2})-?[2-9]\d{2}-?\d{4}$/);
	}, "Please specify a valid US phone number");
	
	jQuery.validator.addMethod("zipUS", function(zip, element) {
		return this.optional(element) || zip.match(/^\d{5}(-\d{4})?$/);
	}, "Please specify a valid US zip code. Ex: 92660 or 92660-1234");
	
	jQuery.validator.addMethod("cvv", function(cvv, element) {
		return this.optional(element) || cvv.match(/^\d{3,4}$/);
	}, "Security Code is invalid");	

	er_number_only();
	
	// YouTube video
	$('.tooltip_playvideo').CreateBubblePopup({
    position: 'top',
    align: 'center',
    distance: '50px',
    tail: {
      align: 'middle',
      hidden: false
    },
    selectable: true,
    innerHtml: '<div class="tip_play-video">click to play this video</div>',
    innerHtmlStyle: {
      color: '#333333',
      'text-align': 'center'
    },
    themeName: 'azure',
    themePath: '/images/ui-plugins/bubblepopup'
  });
  youtube_video_links();
  $('input.noautocomplete').doTimeout(2000, function(){
    $(this).attr("autocomplete", 'off');
  });
  
  // forms & error fields
  $(".field_with_errors, .errorExplanation").each(function() {
    $(this).addClass("ui-corner-all");
  });
  
  shadow_on();
	
  
});


function initialize_buttons(){
	$(function() {
		$(".add_to_cart").button({
	            icons: {
	                primary: 'ui-icon-plus'
	            }})
			.click( function(e) {
				var qty = $(this).siblings('input.er_product_quantity').val() == undefined ? '' : "&qty="+$(this).siblings('input.er_product_quantity').val()
				$.ajax({url:"/carts/add_to_cart?id="+this.id.replace('add_to_cart_', '')+qty});
				$(this).button({disabled: true});
				_gaq.push(['_trackEvent', 'Cart', 'Add To Cart', $(this).attr('rel')]);
			})
	});
		
	$(function() {
	  $(".wishlist").button()
	    .click(function() {
	      $.ajax({url:"/add_to_list?id="+this.id.replace('add_to_list_', '')});
				_gaq.push(['_trackEvent', 'Lists', 'Add To Default List', $(this).attr('rel')]);
				$(this).button({disabled: true, label: 'please wait...'});
			})
	    .next()
	    .button({
	      text: false,
	      icons: {primary: "ui-icon-triangle-1-s"}
	    })
	    .click( function() {
				$(this).parent('p').next('.wishlist_loader').show();
				$.ajax({url:"/users/get_lists?id="+this.id.replace('add_to_list_', ''), context: $(this).parent('p'), success: function(data){
				        $(this).next('.wishlist_loader').hide();
								if (data[0] != '$') $(this).after(data);
				      }});			
			})
	    .parent()
	    .buttonset();
	});
	
	$(function() {
		$(".jqui_button").button();
	});
	$(function() {
		$(".jqui_save").button({icons: {primary: 'ui-icon-disk'}})
	});
	$(function() {
		$(".jqui_ok").button({icons: {primary: 'ui-icon-check'}});
	});
	$(function() {
		$(".jqui_cancel").button({icons: {primary: 'ui-icon-closethick'}});
	});
	$(function() {
		$(".jqui_new").button({icons: {primary: 'ui-icon-plusthick'}});
	});
	$(function() {
		$(".jqui_clone").button({icons: {primary: 'ui-icon-newwin'}});
	});
	$(function() {
		$(".jqui_trash").button({icons: {primary: 'ui-icon-trash'}});
	});
	$(function() {
		$(".jqui_back").button({icons: {primary: 'ui-icon-triangle-1-w'}});
	});
	$(function() {
		$(".jqui_search").button({icons: {primary: 'ui-icon-search'}});
	});
	$(function() {
		$(".jqui_account").button({icons: {primary: 'ui-icon-person'}});
	});
	$(function() {
		$(".jqui_admin").button({icons: {primary: 'ui-icon-wrench'}});
	});
	$(function() {
		$(".jqui_destroy_min").button({icons: {primary: 'ui-icon-trash'}, text: false});
	});
	$(function() {
		$(".jqui_show_min").button({icons: {primary: 'ui-icon-document'}, text: false});
	});
	$(function() {
		$(".jqui_edit_min").button({icons: {primary: 'ui-icon-pencil'}, text: false});
	});
	$(function() {
		$(".jqui_cart_min").button({icons: {primary: 'ui-icon-cart'}, text: false});
	});	
	$(function() {
		$(".jqui_messages_min").button({icons: {primary: 'ui-icon-mail-closed'}, text: false});
	});	
	$(function() {
		$(".jqui_out_of_stock").button({icons: {primary: 'ui-icon-alert'}, disabled: true});
	});
	$(function() {
		$(".jqui_clipboard").button({icons: {primary: 'ui-icon-clipboard'}});
	});
	$(function() {
		$(".jqui_show").button({icons: {primary: 'ui-icon-document'}});
	});
	$(function() {
		$(".jqui_move_min").button({icons: {primary: 'ui-icon-extlink'}, text: false});
	});
};

function order_comment() {
	$('#order_comment').click(function() {
    $(this).find('span').toggleClass('ui-icon-triangle-1-s')
    $(this).find('span').toggleClass('ui-icon-triangle-1-e')
    $(this).next().toggle();
    return false;
  }).next().hide();
};

function initialize_show_cart() {
	$(".show_cart")
//		.button({icons: {primary: 'ui-icon-cart'}})
		.click(function() {
			_gaq.push(['_trackEvent', 'Cart', 'Show Cart']);
			show_cart();
			setTimeout("$.fancybox.resize()", 1600);
			return false;
		});
}

function show_cart() {
	$.fancybox({
			'padding'	: 10,
			'autoScale'	: false,
			'scrolling' : 'auto',
			'speedIn'	:	500, 
			'speedOut' :	200,
			'href' : '/cart',
			'width'	: 860,
			'autoDimensions': true,
			'title'			: false,
			'onComplete' : function() {
        if ($("#fancybox-wrap:visible").length > 0) $('.save_for_later').hide();
				setTimeout("$.fancybox.resize()", 100);
			}
		});
	setTimeout("$.fancybox.resize()", 900);
	return false;
}

function add_fields(link, association, content) {  
  var new_id = new Date().getTime();  
  var regexp = new RegExp("new_" + association, "g");  
  $(link).before(content.replace(regexp, new_id));
  
  // resize the column's height
  var column_height = $(link).closest("li").height() + 100;
  $(link).closest("li").css({"height": (column_height) + "px"});
}

function split(val) {
	return val.split(/,\s*/);
}
function extractLast(term) {
	return split(term).pop();
}

var single_auto_complete_options = {
	source: function(request, response) {
	  $.ajax({
    	url: "/products_autocomplete",
    	dataType: 'text json',
    	data: {term: extractLast(request.term)},
    	success: function( data ) {response(data)}
    });
	},
	search: function() {
		var term = extractLast(this.value);
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
}

var auto_complete_options = {
	source: function(request, response) {
	  $.ajax({
    	url: "/products_autocomplete",
    	dataType: 'text json',
    	data: {term: extractLast(request.term)},
    	success: function( data ) {response(data)}
    });
	},
	search: function() {
		// custom minLength
		var term = extractLast(this.value);
		if (term.length < 2 || term.replace(/^All\s?/, '').length < 2) {
			return false;
		}
	},
	focus: function() {
		// prevent value inserted on focus
		return false;
	},
	select: function(event, ui) {
		var terms = split( this.value );
		// remove the current input
		terms.pop();
		terms = terms.concat(split(ui.item.value), [""])
		this.value = uniq(terms).join(", ");
		var item_nums = split(ui.item.value);
		for(var i = 0; i < item_nums.length; i++)
	  { 
	    $(this).parent().find('.admin_checkboxes [type=checkbox][value='+item_nums[i]+']').attr('checked', true);
	  }		
		return false;
	}
};
	
function sortable_tabs(product) {
	$("#tabs").sortable({update: function(event, ui) {
			$.ajax({url:"/admin/products/reorder_tabs?id="+product+"&"+$("#tabs").sortable('serialize')});
	  }
	});
	$("#tabs").disableSelection();
};

function fancyloader(text) {
  $.fancybox({
    'hideOnOverlayClick' : false,
		'padding'	: 10,
		'autoScale'	: true,
		'speedIn'	:	500,
		'speedOut' : 200,
		'showCloseButton'	:	false,
		'showNavArrows'	:	false,
		'enableEscapeButton' :	false,
		'overlayOpacity' :	0.7,
		'width'	: 860,
		'title'	: false,
		'content'	: '<div style="text-align:center;width: 260px;"><p>'+text+'</p><img src="/images/ui-objects/loader-ajax_bar.gif" /></div>'
	});
	setTimeout("$.fancybox.resize()", 1000);
}

function doRound(x, places) {
	return Math.round(x * Math.pow(10, places)) / Math.pow(10, places);
}

function update_net(field, currency, vat_rate) {
	$('#product_msrp_' + currency).val(doRound(field.val()/((vat_rate / 100) + 1), 2));
}

function update_gross(field, currency, vat_rate) {
	$('#msrp_'+currency+'_gross').val(doRound(field.val() * ((vat_rate / 100) + 1), 2));
}

// to access parameters in the url
$.extend({
  getUrlVars: function(){
    var vars = [], hash;
    var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
    for(var i = 0; i < hashes.length; i++)
    {
      hash = hashes[i].split('=');
      vars.push(hash[0]);
      vars[hash[0]] = hash[1];
    }
    return vars;
  },
  getUrlVar: function(name){
    return $.getUrlVars()[name];
  }
});

// case insensitive :contains selector - :icontains
$.expr[':'].icontains = function(obj, index, meta, stack){ 
	return (obj.textContent || obj.innerText || jQuery(obj).text() || '').toLowerCase().indexOf(meta[3].toLowerCase()) >= 0; 
};

function check_items_checkboxes(element, model) {
	if (model == undefined) var model = 'product';
	if (element.find('.'+model+'_autocomplete').val() == undefined) return false;
	$(element).find('.admin_checkboxes [type=checkbox]').attr('checked', false);
  var item_nums = element.find('.'+model+'_autocomplete').val().split(/,\s*/);
  for(var i = 0; i < item_nums.length; i++)
  { 
    $(element).find('.admin_checkboxes [type=checkbox][value='+item_nums[i]+']').attr('checked', true);
  }
};

function check_items_to_item_num_field(element, model) {
	if (model == undefined) var model = 'product';
	var text_field = $(element).parents('.'+model+'s_helper').find('.'+model+'_autocomplete');
	if (text_field.val() == undefined) return false;
	var items = split(text_field.val())
	if ($(element).attr('checked')) {
		items.push(element.value);
	} else{
		items.splice(items.indexOf(element.value),1);
	};
	if (items.indexOf("") >= 0) items.splice(items.indexOf(""),1);
	text_field.val(uniq(items).join(", "));
};

// removes duplicate elements from an array
function uniq(array) {
	for(var i = 0; i < array.length; i++)
  { 
		if (array.indexOf(array[i]) != array.lastIndexOf(array[i])) array.splice(array.lastIndexOf(array[i]),1);
  }
	return array;
}

function calculate_sale_price(price, discount, discount_type) {
	if (discount_type == "0"){
		return doRound(price - (0.01 * discount * price), 2);
	} else if (discount_type == "1") {
		return price - discount > 0 ? price - discount : 0.0;
	} else if (discount_type == "2") {
		return discount;
	}
}

var megapanel_shadow_options = { autoresize: false, imageset: 6, imagepath: "/images/ui-plugins/shadowOn" }

// Mega Menu Hover functions
function megamenuHoverOver() {
  
  // resize & position the megapanel
  var siteWidth = 950;
  var panelWidth = 0;
  var xOrigin = 0;
  var xCoord = 0;
  var panelOverhang;

  if ($('#nav_megamenu ul').position().left < 0) {
    xOrigin = Math.abs($('#nav_megamenu ul').position().left) - $(this).position().left;
  } else {
    xOrigin = -(Math.abs($('#nav_megamenu ul').position().left) + $(this).position().left);
  }
  
  if ($(this).find('.megapanel').hasClass('full-width')) { // for full-width megapanels; calculate correct left coordinate
    xCoord = xOrigin;
  } else { // for all other (content-width) megapanels
    $(this).find('.megapanel ul[class*="wrap"]').each(function(){
      panelWidth += $(this).width();
      panelWidth += parseInt($(this).css("padding-left"), 10);
    })
    $(this).find('.megapanel').css({ "width": (panelWidth) + "px", "padding-right": "10px" }); // resize megapanel to fit content width
    
    if ($(this).find('.megapanel').hasClass('reverse')) { // for 'reverse layout' megapanels
      xCoord = $(this).width() - panelWidth;
    }
    
    panelOverhang = (siteWidth + xOrigin) - (panelWidth + 10);
    
    if (panelOverhang > 0) {
      xCoord = xCoord -= 1; // nudge to align with tab
    } else {
      xCoord = panelOverhang; // right align panel with the site
    }
  }

  $(this).find('.megapanel').css({ "left": (xCoord) + "px" }); // reset the left coordinate of the subpanel
  
  // set mega-item hover styles for Sizzix US & Ellison Education
  if (current_system == "szus") {
    var meganav_hover_bg = "#e3dfd1";
    var meganav_hover_border = "#d0c7a9";
  } else if (current_system == "eeus" || current_system == "eeuk") {
    var meganav_hover_bg = "#e1e1e1";
  } else {
    var meganav_hover_bg = "transparent";
  }

  $(this).css({ "background-color": meganav_hover_bg });
  if (current_system == "szus") {
    $(this).css({ "border": "1px solid " + meganav_hover_border, "border-bottom": "0px" });
  }
  
  // set mega-item hover styles for Sizzix UK & Ellison Retailers
  if (current_system == "szuk") {
    var meganav_hover = "#ffffcc";
  }
  if (current_system == "erus") {
    var meganav_hover = "#6382e0";
  }
  
  if (current_system == "szuk" || current_system == "erus") {
    $(this).find('a.megalink').css({ "color": meganav_hover });
  }
  
  // render the megapanel
  $(this).find('.megapanel').stop().slideDown(15, function() {
    if (current_system != "szus") {
      $(this).shadowOn(megapanel_shadow_options);  // drop shadow for mega menu subpanel
    }
  });
}

function megamenuHoverOut() {
  
  // reset mega-item hover styles for Sizzix US & Ellison Education
  if (current_system == "szus") {
    var meganav_hoverout_border = "#f7f7f5";
  } else {
    var meganav_hover_bg = "transparent";
  }
  
  $(this).css({ "background-color": "transparent" });
  if (current_system == "szus") {
    $(this).css({ "border-color": meganav_hoverout_border });
  }
  
  // set mega-item hover styles for Sizzix UK & Ellison Retailers
  if (current_system == "szuk") {
    var meganav_hoverout = "#eeeeee";
  }
  if (current_system == "erus") {
    var meganav_hoverout = "#eeeeee";
  }
  
  if (current_system == "szuk" || current_system == "erus") {
    $(this).find('a.megalink').css({ "color": meganav_hoverout });
  }  

  // hide the megapanel
  $(this).find('.megapanel').stop().slideUp(15, function() {
    $(this).shadowOff();
  });
}

function toggle_visual_asset_type(child_index) {
	$('.visual_asset_'+child_index+' .type_specific').hide();
	if ($('#landing_page_visual_assets_attributes_'+child_index+'_asset_type').length > 0) $('.visual_asset_'+child_index+' .'+$('#landing_page_visual_assets_attributes_'+child_index+'_asset_type').val()).show();
	if ($('#shared_content_visual_assets_attributes_'+child_index+'_asset_type').length > 0) $('.visual_asset_'+child_index+' .'+$('#shared_content_visual_assets_attributes_'+child_index+'_asset_type').val()).show();
	if ($('#tag_visual_assets_attributes_'+child_index+'_asset_type').length > 0) $('.visual_asset_'+child_index+' .'+$('#tag_visual_assets_attributes_'+child_index+'_asset_type').val()).show();
}
function toggle_child_visual_asset_type(child_index, value) {
	$('.visual_asset_child_'+child_index+' .type_specific').hide();
	$('.visual_asset_child_'+child_index+' .'+value).show();
}

function youtube_video_links() {
	$(".fancyvideo").live('click', function() {
  	$.fancybox({
  			'padding' : 0,
  			'autoScale' : false,
  			'transitionIn' : 'none',
  			'transitionOut' : 'none',
  			'title' : this.title,
  			'width' : 680,
  			'height' : 495,
  			'href' : this.href.replace(new RegExp("watch\\?v=", "i"), 'v/'),
  			'type' : 'swf',
  			'swf' : {
  			  'wmode' : 'transparent',
  				'allowfullscreen'	: 'true', 
  				'allownetworking' : 'internal'
  			}
  		});

  	return false;
  });
}

var payment_validator_options = {
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
		// $('#proceed_checkout').ajaxSubmit();
    _gaq.push(['_trackEvent', 'Cart', 'Place Order']);
    fancyloader('Your order is being processed. Thank you for your patience!');
    $('#proceed_checkout').callRemote();
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
      creditcard: "This not a valid Credit Card Number."
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
