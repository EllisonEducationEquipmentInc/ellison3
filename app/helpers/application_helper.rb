module ApplicationHelper
		
	include ShoppingCart
	include Rack::Recaptcha::Helpers
		
	# returns checkboxes for systems
	def system_enabled(object)
		ELLISON_SYSTEMS.inject("") do |buffer, sys|
			checked = instance_eval("@#{object}").try(:systems_enabled).include?(sys) rescue false
		  buffer << hidden_field_tag(object + '[systems_enabled][]', sys) if checked && !has_write_permissions?(sys)
			buffer << "#{check_box_tag(object + '[systems_enabled][]', sys, checked, :id => "#{object}_systems_enabled_#{sys}", :disabled => !has_write_permissions?(sys))} <span #{'class="current_system"' if sys == current_system}>#{sys.upcase}</span>"
		end.html_safe
	end
	
  def display_product_price_cart(product)
    if product.respond_to?(:custom_price) && product.custom_price
      "<span class='custom-price'>#{number_to_currency(gross_price(product.price))}</span>"
    elsif product.respond_to?(:coupon_price) && product.coupon_price
      "<span class='coupon-price'>#{number_to_currency(gross_price(product.price))}</span>"
    elsif is_er? && product.respond_to?(:retailer_price) && product.retailer_price == product.price
      "<span class='msrp'>#{number_to_currency(gross_price(product.price))}</span>"
    elsif product.sale_price && gross_price(product.sale_price) < gross_price(product.msrp) && product.sale_price <= product.price
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
		regular_price = gross_price(product.price(:time => date)) if product.price(:time => date) < product.msrp && product.sale_price(date) != product.price(:time => date)
    wholesale_price = gross_price(product.wholesale_price(:time => date))
		sale_price = gross_price(product.sale_price(date)) if product.sale_price(date) && product.sale_price(date) <= product.price(:time => date)
		if is_er? && sale_price && sale_price >= product.retailer_price
		  regular_price = sale_price
		  sale_price = nil
		end
    p = ""
    p << "#{is_er? ? 'MSRP' : 'Regular Price: ' if with_text}<span class='msrp#{' old-price' if ecommerce_allowed? && (coupon || regular_price || sale_price)}'>#{number_to_currency msrp}</span> #{'<br />' if line_break}"
    if ecommerce_allowed?
      p << "#{'Wholesale Price: ' if with_text}<span class='old-price'>#{number_to_currency wholesale_price}</span> " if is_er? && (regular_price && regular_price < wholesale_price || sale_price && sale_price < wholesale_price)
      er_label = if regular_price && regular_price == wholesale_price && !sale_price
        "Wholesale Price: "
      else
        "Special Price: "
      end
        
      if regular_price
        p << "#{(product.outlet ? 'Closeout: ' : is_er? ? er_label : 'Sale Price: ') if with_text}<span class='special-price#{' old-price' if coupon || sale_price} #{'sale-price' if is_sizzix_us? && product.outlet}'>#{number_to_currency regular_price}</span> "
        if product.outlet && with_text
          p << "<br /><span class='percent-saved'>You Save #{product.saving}%</span>"
        end
      end
      if sale_price
        p << "#{'Sale Price: ' if with_text}<span class='sale-price'>#{number_to_currency sale_price}</span> "
      end
    end
    p.html_safe
	end
	
	def add_to_cart_button(product, class_name = 'add_to_cart')
	  return '' unless ecommerce_allowed?
	  @product_obj = product
    html = <<-HTML
- if is_er?
  = label_tag "quantity_#{product.id}", "Qty: (Min. #{product.minimum_quantity})"
  = text_field_tag "quantity_#{product.id}", @product_obj.minimum_quantity, :size => 3, :class => "er_product_quantity", :onchange => "if ($(this).val() < #{product.minimum_quantity}) {$(this).val(#{product.minimum_quantity});alert('Minimum Quantity Required for this product is: #{product.minimum_quantity}')}"
  %br
- if @product_obj.pre_order?
  %button{:class => "#{class_name}", :id => "add_to_cart_#{product.id}", :rel => "#{product.item_num}", :alt => "", :title => "Add Product to Shopping Bag to Pre-Order"}== Pre-Order
- elsif backorder_allowed? && @product_obj.out_of_stock? && @product_obj.listable?
  %button{:class => "#{class_name}", :id => "add_to_cart_#{product.id}", :rel => "#{product.item_num}", :alt => "Add Product to Shopping #{cart_name.capitalize}", :title => "Add Product to Shopping #{cart_name.capitalize}"}== Add to #{cart_name.capitalize} +
- elsif @product_obj.out_of_stock?
  - if is_uk?
    = link_to "Check availability at your Local Retailer", stores_path
  - else
    .jqui_out_of_stock Out of Stock
- elsif @product_obj.suspended?
  .jqui_out_of_stock Retired
- elsif @product_obj.available?
  %button{:class => "#{class_name}", :id => "add_to_cart_#{product.id}", :rel => "#{product.item_num}", :alt => "Add Product to Shopping #{cart_name.capitalize}", :title => "Add Product to Shopping #{cart_name.capitalize}"}== Add to #{cart_name.capitalize} +
- elsif @product_obj.not_reselable?
  %span.message= @product_obj.send "availability_message_#{current_system}"
- else
  .jqui_out_of_stock WTF??
- unless @product_obj.suspended? || @users_list
  %p.buttonset{:id => "wishlist_buttons_#{product.id}"}
    %button.wishlist{:id => "add_to_list_#{product.id}", :rel => "#{product.item_num}", :alt => "Add Product to My Default List", :title => "Add Product to My Default List"} Add to My List
    %button.select{:id => "add_to_list_#{product.id}", :rel => "#{product.item_num}"} Select a list
  .wishlist_loader{:style => "display:none"}= image_tag('/images/ui-objects/loader-ajax_fb.gif')
HTML
    Haml::Engine.new(html).render(self)
	end
	
	def link_to_add_fields(name, f, association, build = false)  		
	  new_object = build ? f.object.send(association).build : f.object.relations[association.to_s].klass.new 
	  fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|  
	    render(new_object, :f => builder)  
	  end  
	  link_to_function(name, ("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"), :class => "jqui_new add_fields_link").html_safe
	end
	
	def add_fields_function(dom_id, f, association)  		
	  new_object = f.object.relations[association.to_s].klass.new 
	  fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|  
	    render(new_object, :f => builder)  
	  end  
	  ("add_fields($('##{dom_id} > a.add_fields_link'), \"#{association}\", \"#{escape_javascript(fields)}\")").html_safe
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
    .title= link_to product.name, product_url(:item_num => product.url_safe_item_num, :name => product.name.parameterize)
    .price= display_product_price(product)
  = add_to_cart_button(product)
HTML
		products.map {|e| Haml::Engine.new(html).render(self, :product => e)}.join("<div class='plus_sign ui-icon ui-icon-plusthick'></div>").html_safe
	end
	
	def required_label(f, field, options = {})
	  label = options[:label] || field.to_s.humanize
	  f.label field, "<span class='required'>#{label}</span>".html_safe, :style => "width: #{options[:label_size]}"
	end
	
	def required_label_if(condition, f, field, options = {})
	  label = options[:label] || field.to_s.humanize
	  condition ? required_label(f, field, {:label => "#{label}", :label_size => options[:label_size]}) : (f.label field, "#{label}", :style => "width: #{options[:label_size]}")
	end

	def required_field(label = '')
		label + content_tag(:span, " * ", :style => "color:#FF0000")
	end
	
	def required_field_if(condition, label = '')
		condition ? required_field(label) : label
	end
	
	def spinner
		image_tag('/images/ui-objects/loader-ajax.gif', :class => 'spinner').html_safe
	end
	
	def loader_bar
		image_tag('/images/ui-objects/loader-ajax_fb.gif', :class => 'spinner').html_safe
	end

	def facebook_like
	  if params[:controller] == 'index' && params[:action] == 'idea'
  	  %(<iframe src="http://www.facebook.com/plugins/like.php?href=#{request.url}&amp;layout=button_count&amp;show_faces=false&amp;width=450&amp;action=like&amp;colorscheme=light&amp;height=21" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:450px; height:21px; margin: 0" allowTransparency="true"></iframe>).html_safe
  	else
  		%(<iframe src="http://www.facebook.com/plugins/like.php?href=#{request.url}&amp;layout=box_count&amp;show_faces=false&amp;width=140&amp;action=like&amp;colorscheme=light&amp;height=65" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:140px; height:65px;" allowTransparency="true"></iframe>).html_safe
  	end
	end
	
	def facet_to_param(facet)
	  facet.to_s.gsub(/_(#{ELLISON_SYSTEMS.join("|")})$/, "")
	end
	
	def facet_2_filtername(facet)
	  facet.name == :item_group ? "Brand" : facet.name.to_s.gsub("_#{current_system}", "").humanize
	end
	
	def catalog_breadcrumbs
	  r = ''
	  unless params[:q].blank?
	    r << keyword_label
	    r << link_to_function("x", "location.hash = $.param.fragment( location.hash, {q: '', facets: $.deparam.fragment()['facets'], page: 1}, 0 )", :class => "keyword_remove")
	    r << "<br />"
	  end 
	  unless @breadcrumb_tags.blank? && params[:price].blank? && params[:saving].blank? && params[:brand].blank?
	    breadcrumbs = [link_to_function("<span class='dontprint'>All</span><span class='dontdisplay'>Search Filters: </span>".html_safe, "location.hash = ''")] #[]
	    @breadcrumb_tags.each do |tag|
	      breadcrumbs << link_to(tag.name, "#", :rel => tag.facet_param, :class => "tag_breadcrumb") + "<span class='dontdisplay'>, </span> ".html_safe + link_to("x", "#", :title => "Remove #{tag.name}", :rel => tag.facet_param, :class => "tag_breadcrumb_remove")
	    end
	    breadcrumbs << price_label + ' ' + link_to("x", "#", :rel => params[:price], :title => "remove price", :class => "price_breadcrumb_remove") unless params[:price].blank?
	    breadcrumbs << saving_label + ' ' + link_to("x", "#", :rel => params[:saving], :title => "remove saving", :class => "saving_breadcrumb_remove") unless params[:saving].blank?
	    params[:brand].present? && params[:brand].split(",").each do |brand| 
	      breadcrumbs << brand  + ' ' + link_to("x", "#", :rel => brand.gsub(" ", "+"), :title => "remove item_group", :class => "item_group_breadcrumb_remove") 
	    end
	    r << breadcrumbs.join("<span class='breadcrumb_arrow dontprint'> > </span>".html_safe)
	    r << javascript_tag do
	      <<-JS
	      $(function() {
      		$('.tag_breadcrumb').click(function() {
      		    var facets = $.deparam.fragment()['facets'].split(',');
      		    facets.splice(facets.indexOf($(this).attr('rel'))+1);        
              location.hash = $.param.fragment( location.hash, {facets: facets.join(','), page: 1}, 0 );
        			return false;
        		});
      		$('.tag_breadcrumb_remove').click(function() {
      		    var facets = $.deparam.fragment()['facets'].split(',');
      		    facets.splice(facets.indexOf($(this).attr('rel')),1);        
              location.hash = $.param.fragment( location.hash, {facets: facets.join(','), page: 1}, 0 );
        			return false;
        		});
      		$('.price_breadcrumb_remove').click(function() {       
              location.hash = $.param.fragment( location.hash, {price: '', page: 1}, 0 );
        			return false;
        		});
      		$('.saving_breadcrumb_remove').click(function() {       
              location.hash = $.param.fragment( location.hash, {saving: '', page: 1}, 0 );
        			return false;
        		});
      		$('.item_group_breadcrumb_remove').click(function() {       
      		    var brands = $.deparam.fragment()['brand'].split(',');
      		    brands.splice(brands.indexOf($(this).attr('rel'))+1);
              location.hash = $.param.fragment( location.hash, {brand: brands.join(','), page: 1}, 0 );
        			return false;
        		});
      	});
	      JS
	    end
	  end
	  r.html_safe
	end
	
	def price_label
	  PriceFacet.instance.get_label(params[:price], false, outlet?) unless params[:price].blank?
	end
	
	def saving_label
	  PriceFacet.instance.get_label(params[:saving], true) unless params[:saving].blank?
	end
	
	def keyword_label
	  "Search Keywords: #{params[:q]} " unless params[:q].blank?
	end
	
	def sortable(column, title = nil)  
    title ||= column.titleize  
    css_class = "sortable_header"
    css_class += (column == sort_column) ? " current #{sort_direction}" : ''  
    direction = (column == sort_column && sort_direction == "asc") ? "desc" : "asc"  
    content_tag :th, :class => "ui-widget" do
      arrow(column == sort_column ? direction : nil ) + link_to(title, request.query_parameters.merge(:order => column, :direction => direction), {:class => css_class})
    end
  end
  
  def arrow(direction = nil)
    direction = case direction
    when "asc"
      "s"
    when "desc"
      "n"
    end
    content_tag(:span, "", :class => "arrow ui-icon " + (direction ? "ui-icon-triangle-1-#{direction}" : "ui-icon-triangle-2-n-s")).html_safe
  end
  
  def alert_wrapper(content = '', &block)
    content_tag :div, :class => "ui-widget" do
      content_tag :div, :class => "ui-state-error ui-corner-all", :style => "padding: 0 .7em;" do
        content_tag :p do
          content_tag(:span, '', :class => "ui-icon ui-icon-alert", :style => "float: left; margin-right: .3em;") + (block_given? ? capture(&block) : content)
        end
      end
    end
  end
	
	def youtube_video(text)
	  return text if text.blank?
	  new_text = text.dup
	  text.scan /\[YOUTUBE\].+?\[\/YOUTUBE\]/ do |match|
	    text_to_replace, youtube_video_id = match, match[/\[YOUTUBE\](.+)\[\/YOUTUBE\]/, 1]
	    embeded_code = <<-HTML
  	  <object width="480" height="385"><param name="movie" value="http://www.youtube.com/v/#{youtube_video_id}?fs=1&amp;hl=en_US"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/#{youtube_video_id}?fs=1&amp;hl=en_US" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="480" height="385"></embed></object>
  	  HTML
  	  .html_safe
  	  new_text.gsub!(text_to_replace, embeded_code)
	  end
	  new_text
	end
	
	def video_thumbnail(youtube_id)
	  content_tag :div, :class => "thumbnail", :style => "background: url('http://i1.ytimg.com/vi/#{youtube_id}/default.jpg') no-repeat center center;" do
	    link_to image_tag("/images/ui-buttons/play-video_on.png"), "http://www.youtube.com/v/#{youtube_id}&amp;feature=youtube_gdata_player&amp;autoplay=1&amp;fs=1", :class => "fancyvideo", :id => youtube_id, :alt => "click to play this video", :title => "click to play this video"
	  end
	end
	
	def uri_append_or_first
	  request.query_parameters.blank? ? "?" : "#{request.fullpath}&"
	end
	
	def idea_name
	  Idea.public_name
	end
	
	def estimated_tax
	  is_uk? && session[:vat_exempt] ? 'Prices do not include V.A.T' : t(:estimated_tax)
	end
	
	def with_buttons?
	  params[:with_buttons] || params[:controller] == 'carts' && params[:action] == 'index'
	end
	
	def cart_name
    cart_name = case current_system
      when "szus" then "bag"
      when "szuk" then "bag"
      when "erus" then "cart"
      when "eeus" then "cart"
      when "eeuk" then "quote"
      else "cart"
    end    
    return cart_name
	end

  def zone_label(zone)
    zone_label = case zone
      when 9 then 'Use this Zone to define Shipping Rates for Hawaii.'
      when 10, 11, 12 then 'unused.'
      when 17 then 'Use this Zone to define Shipping Rates for Alaska.'
      when "APO" then 'Use this Zone to define Shipping Rate for APO/FPO.'
      else nil
    end
    return zone_label
  end
	
end