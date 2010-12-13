module AdminHelper
  
  def admin_systems_checkboxes
    r = ''
    admin_systems.each do |sys|
      r << check_box_tag("systems_enabled[]", sys, params[:systems_enabled] && params[:systems_enabled].include?(sys), :id => nil)
      r << sys
    end
    r.html_safe
  end
  
  def products_helper_tag(name, value = nil, options = {})
    content_tag :div, :class => "products_helper field #{options[:class].try(:html_safe)}" do
      r = label_tag(name, options[:label]).html_safe || sanitize_to_id(name).humanize
      r += tag("br")
      r += text_field_tag(name, value, :size => 150, :class => 'product_autocomplete').html_safe
      r += tag("br")
      r += link_to("All Products Helper", "#", :class => "product_helper_link").html_safe
      r += text_field_tag(:tag_search, nil, :placeholder => "get products by tag name", :class => "product_search_by_tag").html_safe
      r += content_tag(:span, '', :class => 'product_search_selected_tag').html_safe
      r += content_tag(:div, '', :class => 'product_search_by_tag_area').html_safe
      r += javascript_tag do
        <<-JS
          $('.product_helper_link').click(function(e){
            $(this).siblings('.product_search_by_tag').remove();
            $(this).siblings('.product_search_by_tag_area').remove();
            $.ajax({url:'/admin/products/product_helper', context: $(e.currentTarget).parent(), beforeSend: function(){$(this).find('.product_helper_link').replaceWith('#{escape_javascript spinner}')}, success: function(data){$(this).find('.spinner').replaceWith(data);check_items_checkboxes(this)}});
            return false;
          });
          $('##{sanitize_to_id(name)}').autocomplete(auto_complete_options);
          
          $('.product_search_by_tag').autocomplete({
            source: function(request, response) {
          		$.getJSON("/admin/tags/tags_autocomplete", {
          			term: request.term
          		}, response);
          	},
          	search: function() {
          		if (this.value.length < 2) {
          			return false;
          		}
          	},
          	focus: function( event, ui ) {
            				$(this).val( ui.item.label );
            				return false;
            			},
          	select: function(event, ui) {
          	  this.value = '';
          	  $(this).siblings('.product_search_selected_tag').html(ui.item.label);
          	  $.ajax({url:'/admin/products/product_helper_by_tag?id='+ui.item.id, context: $(this).siblings('.product_search_by_tag_area'), beforeSend: function(){$(this).html('#{escape_javascript spinner}')}, success: function(data){$(this).find('.spinner').replaceWith(data);check_items_checkboxes($(this).parent())}});
          		return false;
          	}});
        JS
        .html_safe
      end
    end.html_safe
  end
  
  def ideas_helper_tag(name, value = nil, options = {})
    content_tag :div, :class => "ideas_helper field #{options[:class].try(:html_safe)}" do
      r = label_tag(name, options[:label]).html_safe || sanitize_to_id(name).humanize
      r += tag("br")
      r += text_field_tag(name, value, :size => 150, :class => 'idea_autocomplete').html_safe
      r += tag("br")
      r += link_to("All Ideas Helper", "#", :class => "idea_helper_link").html_safe
      r += javascript_tag do
        <<-JS
          $('.idea_helper_link').click(function(e){
            $.ajax({url:'/admin/ideas/idea_helper', context: $(e.currentTarget).parent(), beforeSend: function(){$(this).find('.idea_helper_link').replaceWith('#{escape_javascript spinner}')}, success: function(data){$(this).find('.spinner').replaceWith(data);check_items_checkboxes(this)}});
            return false;
          });
          $('##{sanitize_to_id(name)}').autocomplete(auto_complete_options);
        JS
        .html_safe
      end
    end.html_safe
  end
  
end
