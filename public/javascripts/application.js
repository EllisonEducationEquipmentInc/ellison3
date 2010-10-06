// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
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
			'titleShow': false
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
	$(".cardpanelshadow").shadowOn({ imageset: 6, imagepath: "/images/ui-backgrounds/shadowOn" });  // drop shadows for cardpanel layout archetype
	$(".megasubpanel").shadowOn({ imageset: 6, imagepath: "/images/ui-backgrounds/shadowOn" });  // drop shadows for cardpanel layout archetype
	$(".product-block").shadowOn({ imageset: 1, imagepath: "/images/ui-backgrounds/shadowOn" });  // drop shadow for product blocks on catalog pages
}

function bind_hashchange () {
	$(window).bind( 'hashchange', function(){
	  var hash = location.hash;
		if (location.pathname.indexOf("/catalog") >= 0)
			$.ajax({url:"/index/search?"+$.param.fragment(), beforeSend: function(){$("#product_catalog").css({opacity: 0.3})}, complete: function(){$("#product_catalog").css({opacity: 1})}});
	});
}

function highlight_keyword () {
	var term = $.getUrlVar('q') || $.deparam.fragment()['q'];
	if (term == undefined) {
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
	
	$(function() {
		$(".tab-block").tabs();
	});
	$(function() {
		$(".accordion-block").accordion();
	});
	
	// mega menu
	$(function(){ 
	  jQuery(".megamenu").megamenu({
	    justify: "right"
	  }); 
  });
  
  $(".megamenu a").FontEffect({
    outline:true,
    outlineWeight: 2,
    outlineColor1: "#81a27b"
  })
	
	// content sliders
  $("#gallery").sudoSlider({
    controlsFade:false,
    prevHtml:'<a href="#" class="prevBtn"> prev </a>',
    ajax: ['/images/_temp/gallery_mockup_003.jpg', '/images/_temp/gallery_mockup_001.jpg', '/images/_temp/gallery_mockup_002.jpg', '/images/_temp/gallery_mockup_003.jpg', '/images/_temp/gallery_mockup_002.jpg', '/images/_temp/gallery_mockup_003.jpg', '/images/_temp/gallery_mockup_001.jpg', '/images/_temp/gallery_mockup_002.jpg', '/images/_temp/gallery_mockup_003.jpg'],
    numeric:true,
    preloadAjax:true,
    imgAjaxFunction: function(t){
        var url = $(this).children().attr('src');	
        $('.controls li a span').eq(t-1).html('<img src="' + url + '" width="60" height="20" />');
    }
  });
  
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
  
  // product carousels
  $(function() {
    $("#bestsellers").jCarouselLite({
      btnNext: ".up_bestsellers",
      btnPrev: ".down_bestsellers",
      vertical: true,
      auto: 5500,
      speed: 2500,
      visible: 1,
      scroll: 1
    });
  });
  $(function() {
    $("#newarrivals").jCarouselLite({
      btnNext: ".up_newarrivals",
      btnPrev: ".down_newarrivals",
      vertical: true,
      auto: 5500,
      speed: 2500,
      visible: 1,
      scroll: 1
    });
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

});


function initialize_buttons(){
	$(function() {
		$(".add_to_cart").button({
	            icons: {
	                primary: 'ui-icon-cart'
	            }})
			.click( function() {
				$.ajax({url:"/carts/add_to_cart?id="+this.id.replace('add_to_cart_', '')});
			})
	});
	
	$(function() {
	  $(".wishlist").button()
	    .click(function() {
	      alert("It will add item immediately to default wishlist");})
	    .next()
	    .button({
	      text: false,
	      icons: {primary: "ui-icon-triangle-1-s"}
	    })
	    .click( function() {alert( "will display a menu to select list" );})
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