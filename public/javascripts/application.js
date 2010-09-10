// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
$(function() {
    $(".wymeditor").wymeditor();
});

$(function (){  
    $('.datetimepicker').datetimepicker({
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

$(document).ready(function(){
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
	
	// lightboxes
	$("a.lightbox").fancybox({
			'transitionIn'	:	'elastic',
			'transitionOut'	:	'elastic',
			'speedIn'		:	500, 
			'speedOut'		:	200, 
			'overlayShow'	:	true
		});
	initialize_buttons();
	
	// shadowOn
	$(".cardpanelshadow").shadowOn({ imageset: 6, imagepath: "/images/ui-backgrounds/shadowOn" });  // drop shadows for cardpanel layout archetype
	$(".product-block").shadowOn({ imageset: 1, imagepath: "/images/ui-backgrounds/shadowOn" });  // drop shadow for product blocks on catalog pages

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

});

$(function() {
	$(".add_to_cart").button({
            icons: {
                primary: 'ui-icon-cart'
            }})
		.click( function() {
			$.ajax({url:"/carts/add_to_cart?id="+this.id.replace('add_to_cart_', '')});
		})
});

function initialize_buttons(){
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
	
};

$(function() {
	$(".show_cart")
//		.button({icons: {primary: 'ui-icon-cart'}})
		.click(function() {
			show_cart();
			return false;
		});
});

function show_cart() {
	$.fancybox({
			'padding'		: 10,
			'autoScale'		: false,
			'speedIn'		:	500, 
			'speedOut'		:	200,
			'href' 	: '/cart',
			'width'	: 860,
			'title'			: false
		});
	setTimeout("$.fancybox.resize()", 600);
	return false;
}

$(function() {
		$(".wishlist")
			.button()
			.click( function() {
				alert( "It will add item immediately to default wishlist" );
			})
		.next()
			.button( {
				text: false,
				icons: {
					primary: "ui-icon-triangle-1-s"
				}
			})
			.click( function() {
				alert( "will display a menu to select list" );
			})
		.parent()
			.buttonset();
	});

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

var auto_complete_options = {
	source: function(request, response) {
		$.getJSON("/admin/products/products_autocomplete", {
			term: extractLast(request.term)
		}, response);
	},
	search: function() {
		// custom minLength
		var term = extractLast(this.value);
		if (term.length < 2) {
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
		// add the selected item
		terms.push( ui.item.value );
		// add placeholder to get the comma-and-space at the end
		terms.push("");
		this.value = terms.join(", ");
		return false;
	}};
	
function sortable_tabs(product) {
	$("#tabs").sortable({update: function(event, ui) {
			$.ajax({url:"/admin/products/reorder_tabs?id="+product+"&"+$("#tabs").sortable('serialize')});
	  }
	});
	$("#tabs").disableSelection();
};

