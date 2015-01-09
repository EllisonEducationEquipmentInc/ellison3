/*! http://tinynav.viljamis.com v1.2 by @viljamis */
(function(a,k,g){a.fn.tinyNav=function(l){var c=a.extend({active:"selected",header:"",indent:"- ",label:""},l);return this.each(function(){g++;var h=a(this),b="tinynav"+g,f=".l_"+b,e=a("<select/>").attr("id",b).addClass("tinynav "+b);if(h.is("ul,ol")){""!==c.header&&e.append(a("<option/>").text(c.header));var d="";h.addClass("l_"+b).find("a").each(function(){d+='<option value="'+a(this).attr("href")+'">';var b;for(b=0;b<a(this).parents("ul, ol").length-1;b++)d+=c.indent;d+=a(this).text()+"</option>"});
e.append(d);c.header||e.find(":eq("+a(f+" li").index(a(f+" li."+c.active))+")").attr("selected",!0);e.change(function(){triggerVideoChange(a(this).val())/*k.location.href=a(this).val()*/});a(f).after(e);c.label&&e.before(a("<label/>").attr("for",b).addClass("tinynav_label "+b+"_label").append(c.label))}})}})(jQuery,this,0);

/* Nav hover rewrite */
var hoverOverMenuItem = function(){
	var meganav_hover, meganav_hover_bg, meganav_hover_border, panelOverhang, panelWidth, siteWidth, xCoord, xOrigin;
	siteWidth = 950;
	panelWidth = 0;
	xOrigin = 0;
	xCoord = 0;
	$(this).addClass('hover');
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
	// $(this).css({
	// 	"background-color": meganav_hover_bg
	// });
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
	if (current_system === "szuk" || current_system === "erus") {
		$(this).find("a.megalink").css({
			color: meganav_hover
		});
	}
	return $(this).find(".megapanel").stop().slideDown(15, function() {
		if (current_system !== "szus") {
			return $(this).shadowOn(megapanel_shadow_options);
		}
	});
};

/* Custom JS */
var sdmReskinFixsidebar = null;
var triggerVideoChange = null;
jQuery(document).ready(function(){
	// Change header search submit button
	jQuery("#searchbar .submitbutton")
		.attr('src', '/reskin_images/transparent.gif')
		.removeAttr('height')
		.removeAttr('width')
		.addClass('ready');

	// Fix catalog page sidebar
	sdmReskinFixsidebar = function(isCallback){
		// Change catalog search submit button
		jQuery("#products_filter input[type=image]")
			.addClass('submitbutton')
			.attr('src', '/reskin_images/transparent.gif')
			.removeAttr('height')
			.removeAttr('width');

		// Change catalog text field
		jQuery("#products_filter #keyword")
			.removeAttr('onblur')
			.removeAttr('onfocus')
			.blur(function(){if (this.value == ''){this.value='Search Within Results';}})
			.focus(function(){if (this.value == 'Search Within Results'){this.value='';}});
		if (jQuery("#products_filter #keyword").val() == "search within these results..."){
			jQuery("#products_filter #keyword").attr('value', "Search Within Results");
		}

		// Hide breadcrumbs if there are none
		jQuery("#catalog_breadcrumbs").css(
			'display',
			jQuery("#catalog_breadcrumbs *").length ? "block" : "none"
		);


		// Add wrapper around #sort for catalog view
		jQuery('.lonely-wrap').remove();
		if (jQuery("#sort").length && !jQuery("#sort").parent().is(".select-wrapper")){
			jQuery("#sort")
				.wrap("<div class='select-wrapper width-100p sort-wrap'></div>");
		}else if (!jQuery("#sort").length){
			jQuery("#product_catalog .toggleview")
				.first()
				.before("<div class='lonely-wrap'>&nbsp;</div>");
		}

		// Add wrapper around #per_page for catalog view
		if (!jQuery("#per_page").parent().is(".select-wrapper")){
			jQuery("#per_page").wrap("<div class='select-wrapper width-100p per-page-wrap'></div>");
		}

		// Fix button text
		jQuery(".add_to_cart .ui-button-text").text(function () {
	        return jQuery(this).text().replace("Add to Bag +", "Add to Bag");
	    });

	    // Remove extra page breaks as they cause this css rule to count improperly:
	    //		#product_catalog .item-block:nth-child(4n)
	    jQuery("#product_catalog .page-break").remove();

	    if (typeof isCallback === 'undefined'){
	    	setTimeout(function(){
	    		sdmReskinFixsidebar(true);
	    	}, 100);
	    }
	}
	sdmReskinFixsidebar();

	// Misc select wrappers
	jQuery("#feedback_subject")
		.wrap("<div class='select-wrapper feedback-subject'></div>");
	jQuery("#stores select#country, #stores select#state, #stores select#radius")
		.each(function(){
			jQuery(this)
				.wrap("<div class='select-wrapper stores store-"+this.id+"'></div>");
		})



	// Add class to admin link wrapper
	jQuery(".megalink-admin")
		.parent()
			.addClass('has-admin-link')
		.parent()
			.addClass('has-admin-link');

	// Remove promo message
	jQuery("#promo_message")
		.remove();

	// Overwrite current JS hover
	jQuery("#nav_megamenu li.megaitem")
		.hoverIntent({
			autoresize: false,
			sensitivity: 2,
			interval: 125,
			timeout: 500,
			over: hoverOverMenuItem,
			out: function(){
				$(this).removeClass('hover');
			},
		});

	// Video page stuff
	if (jQuery("#search_videos").length){
		// Add wrapping class to video page
		jQuery("#content").addClass("video-page");

		// Add wrapper around #per_page for catalog view
		// if (!jQuery("#per_page").parent().is(".select-wrapper")){
		// 	jQuery("#per_page").wrap("<div class='select-wrapper per-page-wrap'></div>");
		// }

		// Write function to change select video filter when we change the select
		triggerVideoChange = function(txt){
			jQuery('.tab-block')
				.tabs("select", 
					jQuery('.ui-tabs-panel').index(jQuery(txt))
				);
			// jQuery(".video_content.ui-tabs-panel")
			// 	.addClass("ui-tabs-hide");
			// jQuery(txt)
			// 	.removeClass("ui-tabs-hide");
		};

		jQuery("#video_keyword")
			.keypress(function(e){
				var code = e.keyCode || e.which;
				if(code == 13 && jQuery("#video_keyword").val().length) {
					jQuery("#video-category .tinynav").val("#search_results");
				}
			});
		jQuery("#search_videos .jqui_search")
			.click(function(){
				if(jQuery("#video_keyword").val().length) {
					jQuery("#video-category .tinynav").val("#search_results");
				}
			});

		// Add html to generate select box
		jQuery(".contentwrap_XXXL .ui-tabs-nav")
			.wrap("<div class='select-wrapper'></div>");
		jQuery(".contentwrap_XXXL .select-wrapper")
			.wrap("<div id='video-category'></div>");

		// Create tinynav select
		jQuery(".contentwrap_XXXL .ui-tabs-nav").tinyNav({
			active : 'ui-state-active'
		});

		jQuery(".select-wrapper")
			.before("<h3>Video Category</h3>");

		jQuery("#search_videos")
			.insertAfter("#video-category");
	}

    // Replace add to bag button text
    jQuery(".add_to_cart .ui-button-text").text(function () {
        return jQuery(this).text().replace("Add to Bag +", "Add to Bag");
    });

    // Add margin to notice if on the same page as .frame_gallery_wide
    if (jQuery(".frame_gallery_wide").length){
    	jQuery(".dontprint.notice, .dontprint.error")
	    	.css({
	    		'margin-bottom' : '40px'
	    	});
    }
    // Add class to warranty page
    if (window.location.href.split('/warranties').length > 1){
    	jQuery('body').addClass("warranties-page");
    }

    //Nth child fixes
    var nthChildFixes = [
    	[
    		"#header #nav_megamenu ul.megalist li.megaitem:nth-child(2) .contentwrap_XS:nth-child(1)",
    		"nth-child-fix-1"
    	],
    	[
    		"#product_catalog .item-block:nth-child(4n)",
    		"nth-child-fix-2"
    	],
    	[
    		"body.bp table.striped tr:nth-child(even) td",
    		"nth-child-fix-3"
    	],
    	[
    		".ui-tabs-panel .item-block:nth-child(5n+1)",
    		"nth-child-fix-4"
    	]
    ];

    // Apply the nth child fixes
    jQuery.each(nthChildFixes, function(key, nthChild){
    	jQuery(nthChild[0]).addClass(nthChild[1]);
    });

    // Make pink buttons
    jQuery(".ui-button-text").each(function(){
    	var btnText = $(this);
    	if (btnText.text().toLowerCase() == 'go to cart'){
    		btnText.parent().addClass('make-me-pink');
    	}
    });
    jQuery("input[type='submit']").each(function(){
    	var btn = $(this);
    	if (btn.val().toLowerCase() == 'go!'){
    		btn.addClass('make-me-pink');
    	}
    });

});
