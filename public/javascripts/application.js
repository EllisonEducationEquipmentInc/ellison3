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

$(function() {
	$(".add_to_cart").button({
            icons: {
                primary: 'ui-icon-cart'
            }});
});

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