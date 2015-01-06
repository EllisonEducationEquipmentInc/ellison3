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

var fixsidebar = null;
jQuery(document).ready(function(){
	// Change header search submit button
	jQuery("#searchbar .submitbutton")
		.attr('src', '/reskin_images/transparent.gif')
		.removeAttr('height')
		.removeAttr('width');

	// Fix catalog page sidebar
	fixsidebar = function(){
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
		if (!jQuery("#sort").parent().is(".select-wrapper")){
			jQuery("#sort").wrap("<div class='select-wrapper sort-wrap'></div>");
		}

		// Add wrapper around #per_page for catalog view
		if (!jQuery("#per_page").parent().is(".select-wrapper")){
			jQuery("#per_page").wrap("<div class='select-wrapper per-page-wrap'></div>");
		}

		// Fix button text
		jQuery(".add_to_cart .ui-button-text").text(function () {
	        return jQuery(this).text().replace("Add to Bag +", "Add to Bag");
	    });

	    // Remove extra page breaks as they cause this css rule to count improperly:
	    //		#product_catalog .item-block:nth-child(4n)
	    jQuery("#product_catalog .page-break").remove();
	}
	setInterval(fixsidebar, 2000);

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

    // Replace add to bag button text
    jQuery(".add_to_cart .ui-button-text").text(function () {
        return jQuery(this).text().replace("Add to Bag +", "Add to Bag");
    });
});

