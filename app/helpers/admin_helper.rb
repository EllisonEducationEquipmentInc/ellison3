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
    content_tag :div, :class => "products_helper field" do
      r = label_tag name, options[:label]
      r += tag("br")
      r += text_field_tag name, value, :size => 100, :class => 'product_autocomplete'
      r += link_to_function "update checkboxes", "check_items_checkboxes($(this).parent())"
      r += tag("br")
      r += link_to "Products Helper", "#", :class => "product_helper_link"
      r += javascript_tag do
        <<-JS
          $('.product_helper_link').click(function(e){
            $.ajax({url:'/admin/products/product_helper', context: $(e.currentTarget).parent(), beforeSend: function(){$(this).find('.product_helper_link').replaceWith('#{spinner}')}, success: function(data){$(this).find('.spinner').replaceWith(data);check_items_checkboxes(this)}});
            return false;
          });
          $("##{name}").autocomplete(auto_complete_options);
        JS
      end
    end.html_safe
  end
  
end
