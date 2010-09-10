module ApplicationHelper
	
	include ShoppingCart
	
	# returns checkboxes for systems
	def system_enabled(object)
		ELLISON_SYSTEMS.inject("") do |buffer, sys|
			checked = instance_eval("@#{object}").try(:systems_enabled).include?(sys) rescue false
			buffer << "#{check_box_tag(object + '[systems_enabled][]', sys, checked, :id => "#{object}_systems_enabled_#{sys}")} #{sys}"
		end.html_safe
	end
	
	def display_product_price(product, options = {})
		date = options[:date] || Time.zone.now
		with_text = options[:with_text] 
    line_break = options[:line_break]
		campaign = options[:campaign]
		show_coupon = options[:show_coupon]
		style = options[:style] ? " style='#{options[:style]}'" : ""
		
		coupon = show_coupon #&& product.coupon_price(get_cart) < product.price
		
		msrp = gross_price product.msrp
		regular_price = gross_price(product.price) if product.price < product.msrp && product.sale_price(date) != product.price
		sale_price = gross_price(product.sale_price(date)) if product.sale_price(date)
		
		p = ""
		p << "<span class='msrp #{'strike_through' if coupon || regular_price || sale_price}'}>#{number_to_currency msrp}</span> "
		p << "<span class='price_special #{'strike_through' if coupon || sale_price}'}'>#{number_to_currency regular_price}</span> "
		p << "<span class='price_sale'>#{number_to_currency sale_price}</span> "
		# TODO: custom price
		#p << "<br><span class='custom_price'>#{product.custom_price}</span>" if product.custom_price
    #p << "<div id=\"custom_price_#{product.id}\">" + "</div>" + link_to('edit', :update => "custom_price_#{product.id}", :url => {:controller => 'cart', :action => 'custom_price', :id => product.id, :with_text => with_text, :line_break => line_break}) if has_sales_manager_permissions? && params[:controller] == 'cart'
		p.html_safe
	end
	
	def add_to_cart_button(product)
    html = <<-HTML
.add_to_cart{:id => "add_to_cart_#{product.id}"}== Add to #{t :cart}
.wishlist_wrapper
  .button.wishlist Add to My List
  .select Select a list
HTML
    Haml::Engine.new(html).render(self)
	end
	
	def link_to_add_fields(name, f, association)  		
	  new_object = f.object.associations[association.to_s].klass.new 
	  fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|  
	    render(new_object, :f => builder)  
	  end  
	  link_to_function(name, ("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"), :class => "jqui_new").html_safe
	end
	
	def link_to_add_tab_collection(name)
		link_to_function("Add #{name.humanize}", ("add_fields(this, \"#{name}\", \"#{escape_javascript(render :partial => "admin/tabs/#{name}", :locals => { name.to_sym => [] })}\")"), :class => "jqui_new").html_safe
	end
	
	def remote_multipart_response(&block)
		if params[:format] == 'js'
			response.content_type = Mime::HTML
	    content = with_output_buffer(&block)
	    text_area_tag 'remotipart_response', content
		else
			yield
		end
  end

	def compatibility_products(products)
		html = <<-HTML
.compatibility_prodcuct
  .compatibility_info
    .item_num= product.item_num
    = image_tag(product.medium_image)
    .title= link_to product.name, product_url(:id => product)
    .price= display_product_price(product)
  = add_to_cart_button(product)
HTML
		products.map {|e| Haml::Engine.new(html).render(self, :product => e)}.join("<div class='plus_sign ui-icon ui-icon-plusthick'></div>").html_safe
	end

	def required_field(label = '')
		label + content_tag(:span, " * ", :style => "color:#FF0000")
	end
	
	def required_field_if(condition, label = '')
		condition ? required_field(label) : label
	end
	
end
