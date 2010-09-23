module ApplicationHelper
	
	include ShoppingCart
	
	# returns checkboxes for systems
	def system_enabled(object)
		ELLISON_SYSTEMS.inject("") do |buffer, sys|
			checked = instance_eval("@#{object}").try(:systems_enabled).include?(sys) rescue false
			buffer << "#{check_box_tag(object + '[systems_enabled][]', sys, checked, :id => "#{object}_systems_enabled_#{sys}")} #{sys}"
		end.html_safe
	end
	
  def display_product_price_cart(product)
		# TODO: coupon price
    if false #product.coupon_price(get_cart) < product.price
      "<span class='price_coupon'>#{number_to_currency(gross_price(product.coupon_price(get_cart)))}</span>"
    elsif product.sale_price && gross_price(product.sale_price) < gross_price(product.msrp)
      "<span class='sale-price'>#{number_to_currency(gross_price(product.price))}</span>"
    else
      "<span class='msrp'>#{number_to_currency(gross_price(product.price))}</span>"
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
		p << "<span class='msrp#{' old-price' if coupon || regular_price || sale_price}'>#{number_to_currency msrp}</span> "
		p << "<span class='special-price#{' old-price' if coupon || sale_price}'>#{number_to_currency regular_price}</span> "
		p << "<span class='sale-price'>#{number_to_currency sale_price}</span> "
		# TODO: custom price
		#p << "<br><span class='custom-price'>#{product.custom_price}</span>" if product.custom_price
    #p << "<div id=\"custom_price_#{product.id}\">" + "</div>" + link_to('edit', :update => "custom_price_#{product.id}", :url => {:controller => 'cart', :action => 'custom_price', :id => product.id, :with_text => with_text, :line_break => line_break}) if has_sales_manager_permissions? && params[:controller] == 'cart'
		p.html_safe
	end
	
	def add_to_cart_button(product)
	  @product = product
    html = <<-HTML
- if @product.pre_order?
  %button.add_to_cart{:id => "add_to_cart_#{product.id}"}== Pre-Order
- elsif @product.out_of_stock?
  .jqui_out_of_stock Out of Stock
- elsif @product.available?
  %button.add_to_cart{:id => "add_to_cart_#{product.id}"}== Add to #{t :cart}
- elsif @product.not_reselable?
  = @product.availability_msg
- else
  .jqui_out_of_stock Suspended
%p.buttonset
  %button.wishlist Add to My List
  %button.select Select a list
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
	
	def spinner
		image_tag "/images/ui-objects/ajax-loader.gif"
	end
	
	def facebook_like
		%(<iframe src="http://www.facebook.com/plugins/like.php?href=#{request.url}&amp;layout=standard&amp;show_faces=true&amp;width=450&amp;action=like&amp;font=lucida+grande&amp;colorscheme=light&amp;height=80" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:450px; height:80px;" allowTransparency="true"></iframe>).html_safe
	end
	
end
