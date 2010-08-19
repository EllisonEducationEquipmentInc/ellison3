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
		$(".button").button();
	});
	$(function() {
		$(".save").button({icons: {primary: 'ui-icon-disk'}})
	});
	$(function() {
		$(".ok").button({icons: {primary: 'ui-icon-check'}});
	});
	$(function() {
		$(".cancel").button({icons: {primary: 'ui-icon-closethick'}});
	});
	$(function() {
		$(".new_button").button({icons: {primary: 'ui-icon-plusthick'}});
	});
	$(function() {
		$(".clone").button({icons: {primary: 'ui-icon-newwin'}});
	});
	$(function() {
		$(".trash").button({icons: {primary: 'ui-icon-trash'}});
	});
};


$(function() {
	$(".show_cart")
		.button({icons: {primary: 'ui-icon-cart'}})
		.click(function() {
			show_cart();
			$.fancybox.resize();
		});
});

function show_cart() {
	$.fancybox({
			'padding'		: 10,
			'autoScale'		: true,
			'speedIn'		:	500, 
			'speedOut'		:	200,
			'href' 	: '/cart',
			'title'			: false
		});
	return false;
}

$(function() {
		$(".wishlist")
			.button()
			.click( function() {
				alert( "It will add item immadiately to default wishlist" );
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
