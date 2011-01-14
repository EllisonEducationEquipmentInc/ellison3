// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

var _gaq = _gaq || [];
var button_label = button_label || '';
var number_only = function(e){if (e.keyCode != 46 && e.keyCode != 8 && e.keyCode != 9 && !String.fromCharCode(e.keyCode).match(/\d+/)) return false}
var outlet = location.pathname.indexOf("/outlet") >= 0;

$(function() {
  $(".wymeditor").wymeditor();
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
			'transitionIn'	:	'elastic',
			'transitionOut'	:	'elastic',
			'speedIn'		:	500, 
			'speedOut'		:	200, 
			'overlayShow'	:	true,
			'titleShow': false,
			'onComplete' : function(){setTimeout("$.fancybox.resize()", 100)}
		});
}

function initialize_facets() {
	$('.facets .head').click(function() {
			$(this).find('span').toggleClass('ui-icon-triangle-1-s')
			$(this).find('span').toggleClass('ui-icon-triangle-1-e')
			$(this).next().toggle();
			return false;
		}).next().show();
}

function shadow_on() {
	// shadowOn
	$(".cardpanelshadow").shadowOn({ imageset: 6, imagepath: "/images/ui-plugins/shadowOn" });  // drop shadows for cardpanel layout archetype
	$(".item-block").shadowOn({ imageset: 1, imagepath: "/images/ui-plugins/shadowOn" });  // drop shadow for item blocks on catalog pages
	$(".item_images").shadowOn({ imageset: 1, imagepath: "/images/ui-plugins/shadowOn" });  // drop shadow for item images on item detail pages
}

function bind_hashchange () {
	$(window).bind( 'hashchange', function(event){
	  var hash = location.hash;
		if (location.pathname.indexOf("/catalog") >= 0 || outlet) {
			var event_name = outlet ? "Outlet" : 'Catalog'
			var outlet_param = outlet ? "outlet=1&" : ''
			_gaq.push(['_trackEvent', event_name, 'Search', $.param.fragment()]);
			$.ajax({url:"/index/search?lang="+$('html').attr('lang')+'&'+outlet_param+$.param.fragment(), beforeSend: function(){$("#product_catalog").css({opacity: 0.3})}, complete: function(){$("#product_catalog").css({opacity: 1})}});
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
      xOffset: 10,
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
    interval: 100, // number = milliseconds for onMouseOver polling interval
    over: megamenuHoverOver, // function = onMouseOver callback (REQUIRED)
    timeout: 500, // number = milliseconds delay before onMouseOut
    out: megamenuHoverOut // function = onMouseOut callback (REQUIRED)
  };
  $("#nav_megamenu li").hoverIntent(hoverconfig); // trigger hover intent with custom configurations	
	  
  // billboard sliders
	// Full Caption Sliding (Hidden to Visible)
  $('.boxgrid.captionfull').hover(function(){
  	$(".cover", this).stop().animate({top:'55px'},{queue:false,duration:160});
  }, function() {
  	$(".cover", this).stop().animate({top:'188px'},{queue:false,duration:160});
  });
	// Full Caption Sliding (Hidden to Visible)
  $('.boxgrid-large.captionfull').hover(function(){
  	$(".cover", this).stop().animate({top:'55px'},{queue:false,duration:160});
  }, function() {
  	$(".cover", this).stop().animate({top:'188px'},{queue:false,duration:160});
  });
  
  // jqueryui tables
  $("table").each(function() {
    $(this).addClass("ui-widget ui-widget-content ui-corner-all");
  });
  $("table thead").each(function() {
    $(this).addClass("ui-state-hover");
  });

	shadow_on();

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
});


function initialize_buttons(){
	$(function() {
		$(".add_to_cart").button({
	            icons: {
	                primary: 'ui-icon-plus'
	            }})
			.click( function() {
				var qty = $(this).siblings('input.er_product_quantity').val() == undefined ? '' : "&qty="+$(this).siblings('input.er_product_quantity').val()
				$.ajax({url:"/carts/add_to_cart?id="+this.id.replace('add_to_cart_', '')+qty});
				_gaq.push(['_trackEvent', 'Cart', 'Add To Cart', $(this).attr('rel')]);
			})
	});
		
	$(function() {
	  $(".wishlist").button()
	    .click(function() {
	      $.ajax({url:"/add_to_list?id="+this.id.replace('add_to_list_', '')});
				_gaq.push(['_trackEvent', 'Lists', 'Add To Default List', $(this).attr('rel')]);
				$(this).button({disabled: true});
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
		$(".jqui_out_of_stock").button({icons: {primary: 'ui-icon-alert'}});
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
			'padding'		: 10,
			'autoScale'		: false,
			'scrolling' : 'auto',
			'speedIn'		:	500, 
			'speedOut'		:	200,
			'href' 	: '/cart',
			'width'	: 860,
			'autoDimensions': true,
			'title'			: false,
			'onComplete' : function(){setTimeout("$.fancybox.resize()", 100)}
		});
	setTimeout("$.fancybox.resize()", 900);
	return false;
}

function add_fields(link, association, content) {  
  var new_id = new Date().getTime();  
  var regexp = new RegExp("new_" + association, "g");  
  $(link).before(content.replace(regexp, new_id));  
}

function split(val) {
	return val.split(/,\s*/);
}
function extractLast(term) {
	return split(term).pop();
}

var single_auto_complete_options = {
	source: function(request, response) {
		$.getJSON("/admin/products/products_autocomplete", {
			term: extractLast(request.term)
		}, response);
	},
	search: function() {
		var term = extractLast(this.value);
		if (term.length < 3) {
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
		$.getJSON("/admin/products/products_autocomplete", {
			term: extractLast(request.term)
		}, response);
	},
	search: function() {
		// custom minLength
		var term = extractLast(this.value);
		if (term.length < 2 || term.replace(/^All\s?/, '').length < 3) {
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
  $.fancybox({  'hideOnOverlayClick'	:	false,
  			'padding'		: 10,
  			'autoScale'		: true,
  			'speedIn'		:	500, 
  			'speedOut'		:	200,
  			'showCloseButton'		:	false,
  			'showNavArrows'		:	false,
  			'enableEscapeButton'	:	false,
  			'overlayOpacity'		:	0.7,
  			'width'	: 860,
  			'title'			: false,
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
  var xCoord  = Math.abs($('#nav_megamenu ul').position().left) - $(this).position().left // calculate correct left coordinate of the subpanel
  $(this).find('.megapanel').css({ "left": (xCoord) + "px" }); // reset the left coordinate of the subpanel
  
  $(this).find('.megapanel').stop().slideDown('fast', function() {
   $(this).shadowOn(megapanel_shadow_options);  // drop shadow for mega menu subpanel
  });
}
function megamenuHoverOut(){
  $(this).find('.megapanel').stop().slideUp('fast', function() {
    $(this).shadowOff();
  });
}

function toggle_visual_asset_type(child_index) {
	$('.visual_asset_'+child_index+' .type_specific').hide();
	if ($('#landing_page_visual_assets_attributes_'+child_index+'_asset_type').length > 0) $('.visual_asset_'+child_index+' .'+$('#landing_page_visual_assets_attributes_'+child_index+'_asset_type').val()).show();
	if ($('#shared_content_visual_assets_attributes_'+child_index+'_asset_type').length > 0) $('.visual_asset_'+child_index+' .'+$('#shared_content_visual_assets_attributes_'+child_index+'_asset_type').val()).show();
	if ($('#tag_visual_assets_attributes_'+child_index+'_asset_type').length > 0) $('.visual_asset_'+child_index+' .'+$('#tag_visual_assets_attributes_'+child_index+'_asset_type').val()).show();
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
            required: true,
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
        },
    }, 
    success: function(label) { 
        label.html(" ").addClass("checked"); 
    },
    submitHandler: function(form) {
      $('#proceed_checkout').callRemote();
			// $('#proceed_checkout').ajaxSubmit();
      _gaq.push(['_trackEvent', 'Cart', 'Place Order']);
      fancyloader('Your order is being processed. Thank you for your patience!');
    },
    
    messages: {
        "payment[first_name]": {
            required: " ",
        },
        "payment[last_name]": {
            required: " ",
        },
        "payment[card_name]": { 
            required: " ",
        },
        "payment[full_card_number]": {
            required: " ",
            creditcard: "invalid"
        },
        "payment[card_security_code]": { 
            required: " ",
        },
        "payment[card_expiration_month]": { 
            required: " ",
        },
        "payment[card_expiration_year]": { 
            required: " ",
        },
    },
};
