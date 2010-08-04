module ApplicationHelper
	
	def system_enabled(object)
		ELLISON_SYSTEMS.inject("") do |buffer, sys|
			checked = instance_eval("@#{object}").try(:systems_enabled).include?(sys) rescue false
			buffer << "#{check_box_tag(object + '[systems_enabled][]', sys, checked)} #{sys}"
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

end
