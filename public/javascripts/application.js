// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
$(function() {
    $(".wymeditor").wymeditor();
});

$(function (){  
    $('#product_start_date').datetimepicker({
					changeMonth: true,
					changeYear: true
				});  
});
$(function (){  
    $('#product_end_date').datetimepicker({
					changeMonth: true,
					changeYear: true
				});  
});