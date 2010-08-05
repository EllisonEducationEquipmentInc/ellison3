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