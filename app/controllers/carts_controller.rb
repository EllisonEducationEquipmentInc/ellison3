class CartsController < ApplicationController

  respond_to :html, :js, :json

  before_filter :authenticate_user!, :only => [:checkout, :proceed_checkout, :quote, :proceed_quote, :quote_2_order, :move_to_cart, :delete_from_saved_list, :save_cod, :cart_upload, :fast_upload]
  before_filter :authenticate_admin!, :only => [:custom_price]
  before_filter :pre_validate_cart, :only => [:checkout, :quote]
  before_filter :admin_user_as_permissions!, :only => [:remove_order_reference, :use_previous_orders_card, :set_upsell]
  before_filter :trackable
  before_filter :no_cache, :only => [:checkout, :quote]
  before_filter :set_vat_exempt, :except => [:add_to_cart, :index, :move_to_cart, :remove_from_cart, :change_quantity, :delete_from_saved_list, :saved_list, :shopping_cart]
  before_filter(:only => [:index]) {|controller| controller.send(:get_cart).reset_item_errors if controller.flash[:alert].blank? }
  #after_filter :reset_cart_item_errors, :only => [:proceed_checkout, :proceed_quote]

  ssl_required :checkout, :proceed_checkout, :quote, :proceed_quote, :quote_2_order
  ssl_allowed :index, :get_shipping_options, :change_shipping_method, :copy_shipping_address, :change_shipping_method, :get_shipping_service, :get_shipping_amount, :get_tax_amount, :get_total_amount,
  :custom_price, :create_shipping, :create_billing, :activate_coupon, :remove_coupon, :shopping_cart, :change_quantity, :add_selected_to_cart, :move_to_cart, :delete_from_saved_list, :last_item,
  :add_to_cart, :remove_from_cart, :save_cod, :get_deferred_first_payment, :forget_credit_card, :set_upsell, :remove_order_reference, :add_to_cart_by_item_num, :use_previous_orders_card, :empty_cart,
  :apply_gift_card, :remove_gift_card

  #verify :xhr => true, :only => [:set_upsell, :get_shipping_options, :get_shipping_amount, :get_tax_amount, :get_total_amount, :activate_coupon, :remove_coupon, :proceed_quote, :use_previous_orders_card,
                                 #:remove_order_reference, :shopping_cart, :change_quantity, :add_selected_to_cart, :save_cod, :add_to_cart_by_item_num, :apply_gift_card, :remove_gift_card] #, :redirect_to => {:action => :index}

  def index
    if get_cart.last_check_at.blank? || get_cart.last_check_at.present? && get_cart.last_check_at.utc < 5.minute.ago.utc
      return unless real_time_cart true
    end
    @title = "Shopping #{cart_name.titleize}"
    @cart_locked = true if params[:locked] == "1"
    @shared_content = SharedContent.cart
    render :index, :layout => false if request.xhr?
  end

  def last_item
    render :last_item, :layout => false
  end

  def add_to_cart
    add_to_cart_do
  end

  def move_to_cart
    add_to_cart_do
    remove_from_saved_list
  end

  def delete_from_saved_list
    remove_from_saved_list
    render :move_to_cart
  end

  def add_selected_to_cart
    render :nothing => true and return if params[:values].blank? || !ecommerce_allowed?
    params[:values].split(",").each do |element|
      item_id, qty = element.split(":")
      @product = Product.find(item_id)
      qty = qty.to_i
      qty = @product.minimum_quantity if is_er? && qty < @product.minimum_quantity
      add_2_cart(@product, qty)
    end
    render :add_to_cart
  end

  def add_to_cart_by_item_num
    @product = Product.available.where(:item_num => params[:item_num].upcase).first
    if @product.present? && @product.orderable? && @product.can_be_added_to_cart?
      qty = is_er? ? @product.minimum_quantity : 1
      add_2_cart(@product, qty)
      render :add_to_cart
    else
      render :js => "$('#item_num').val('');$('#add_to_cart_by_item_num_button').button({disabled: false});alert('Product not found or cannot be added to cart')"
    end
  end

  def remove_from_cart
    @cart_item_id = remove_cart(params[:item_num])
  end

  def change_quantity
    qty = params[:qty].to_i
    if qty < 1
      @cart_item_id = remove_cart(params[:item_num])
      render :remove_from_cart and return
    else
      @cart_item = change_qty(params[:item_num], qty)
    end
  end

  def empty_cart
    clear_cart
  end

  def checkout
    return unless real_time_cart
    session[:user_return_to] = nil
    redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank? || !ecommerce_allowed? || !chekout_allowed?
    set_proper_currency!
    @title = "Checkout"
    @cart_locked, @checkout = true, true
    unless get_user.billing_address && get_user.shipping_address
      @shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email)
      @billing_address = get_user.billing_address || get_user.addresses.build(:address_type => "billing", :email => get_user.email)
    end
    update_user_token
    new_payment
    expires_now
  rescue Exception => e
    Rails.logger.error e.message
    redirect_to(cart_path, :alert => timeout_message)
  end

  def quote
    return unless real_time_cart true
    session[:user_return_to] = nil
    redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank? || !ecommerce_allowed? || !(quote_allowed? || get_cart.pre_order?)
    @title = quote_name
    @cart_locked, @checkout = true, true
    unless get_user.shipping_address
      @shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email)
    end
  end

  def quote_2_order
    @quote = get_user.quotes.active.where(:system => current_system, :_id => BSON::ObjectId(params[:id])).first
    redirect_to root_url and return unless get_user.billing_address && @quote && request.post?
    unless @quote.can_be_converted?
      flash[:alert] = "Your quote cannot be converted to an order this time. Please try again later."
      render :js => "window.location.href = '#{myquote_path(@quote)}'" and return
    end
    new_payment
    @order = Order.new
    @order.copy_common_attributes @quote, :created_at, :_id
    @order.order_items = @quote.order_items
    @order.address ||= get_user.shipping_address.clone
    @cch = Avalara.new(:action => 'calculate', cart: @order, :customer => @order.address, :shipping_charge => @order.shipping_amount, :handling_charge => @order.handling_amount, :total => @order.subtotal_amount, :transaction_id => @order.tax_transaction, :exempt => @order.user.tax_exempt?, :tax_exempt_certificate => @order.user.tax_exempt_certificate )
    @order.update_attributes(:tax_transaction => @cch.transaction_id, :tax_calculated_at => Time.zone.now,  :tax_amount => @cch.total_tax, :tax_exempt => @order.user.tax_exempt?, :tax_exempt_number => @order.user.tax_exempt_certificate) if @cch && @cch.success?
    process_card(:amount => (@quote.total_amount * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => is_uk?, :tokenize_only => !payment_can_be_run?) unless @payment.purchase_order && purchase_order_allowed?
    @order.payment = @payment
    @order.quote = @quote
    process_order @order
    @quote.update_attributes :active => false
    UserMailer.order_confirmation(@order).deliver
    @order.payment.save
    tax_from_order(@order)
    #sign_out(current_user) if admin_signed_in? && current_admin.can_act_as_customer
    render "checkout_complete"
  rescue Exception => e
    @reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
    @error_message = if e.exception.class == Timeout::Error
                       timeout_message
                     else
                       e.backtrace.join("<br />")
                     end
  end

  def proceed_checkout
    redirect_to :checkout and return unless get_user.shipping_address && !get_cart.cart_items.blank?
    return unless real_time_cart
    sleep 0.5
    get_cart.reload
    if @cart.gift_card_applied?
      @valutec = Valutec.new :transaction_sale, card_number: @cart.gift_card_number, amount: total_cart
      unless @valutec.success? && @valutec.authorized? && @valutec.card_amount_used > 0 #&& @cart.gift_card_applied_amount <= @valutec.balance
        @cart.reset_gift_card
        @cart.save
        flash[:alert] = "There was problem authorizing the gift card. Please try again"
        render :js => "window.location.href = '#{checkout_path}'" and return
      end
      cart_total = @valutec.results[:amount_due].to_f
      @gift_card_payment = Payment.new payment_method: "Gift Card", card_number: @valutec.card_number, authorization: @valutec.results[:authorization_code].try(:to_s), paid_at: Time.zone.now, paid_amount: @valutec.card_amount_used, vendor_tx_code: @valutec.identifier, email: get_user.email
      @gift_card_payment.copy_common_attributes(get_user.billing_address) if get_user.billing_address
      params[:payment][:purchase_order] = false if params[:payment].present?
    else
      cart_total = total_cart
    end
    if can_use_previous_payment? && params[:payment] && params[:payment][:use_previous_orders_card]  == "1"
      @payment = Order.find(get_cart.order_reference).payment.dup
      use_payment_token = true
    else
      use_payment_token = false
      new_payment
    end
    @payment.deferred = false if @payment.present? && !get_cart.allow_deferred? || @cart.gift_card_applied?
    @payment.purchase_order = false if @cart.gift_card_applied?
    if @payment.try :deferred
      @payment.number_of_payments = Payment::NUMBER_OF_PAYMENTS
      @payment.frequency = Payment::FREQUENCY
      @payment.deferred_payment_amount = calculate_setup_fee(get_cart.sub_total, get_cart.shipping_amount + calculate_handling, get_cart.tax_amount).last
    end
    cart_to_order(:address => get_user.shipping_address)
    process_card(:amount => (cart_total * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => is_uk?, :tokenize_only => !payment_can_be_run?, :use_payment_token => use_payment_token) unless @payment.purchase_order && purchase_order_allowed? || get_cart.pre_order? || cart_total < 0.01
    @order.payment = @payment unless get_cart.pre_order? || cart_total < 0.01
    @order.gift_card = @gift_card_payment if @gift_card_payment
    process_order(@order)
    clear_cart
    cookies[:tracking], cookies[:utm_source] = nil
    UserMailer.order_confirmation(@order).deliver
    @order.payment.try :save
    #sign_out(current_user) if admin_signed_in? && current_admin.can_act_as_customer
    render "checkout_complete"
  rescue Exception => e
    @reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
    if @valutec && @valutec.authorized?
      Rails.logger.info "!!! voiding GC transaction #{@valutec.results[:authorization_code]}"
      Valutec.new :transaction_void, card_number: @valutec.card_number, request_auth_code: @valutec.results[:authorization_code], identifier: @valutec.identifier
    end
    @error_message = if e.exception.class == Timeout::Error
                       timeout_message
                     else
                       e.message #backtrace.join("<br />")
                     end
    if get_cart.cart_items.blank?
      flash[:alert] = @error_message
      render :js => "window.location.href = '#{catalog_path}'" and return
    end
  end

  def proceed_quote
    redirect_to :quote and return unless (quote_allowed? || get_cart.pre_order?) && get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
    return unless real_time_cart(true)
    sleep 0.5
    get_cart.reload
    cart_to_quote(:address => get_user.shipping_address)
    process_order @quote
    clear_cart
    UserMailer.quote_confirmation(@quote).deliver
    #sign_out(current_user) if admin_signed_in? && current_admin.can_act_as_customer
    render :js => "window.location.href = '#{myquote_path(@quote)}'"
  rescue Exception => e
    @reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
    @error_message = e.message
    if get_cart.cart_items.blank?
      flash[:alert] = @error_message
      render :js => "window.location.href = '#{catalog_path}'" and return
    end
    render :proceed_checkout
  end

  def create_shipping
    get_cart.reset_tax_and_shipping(true)
    @shipping_address = get_user.addresses.build(:address_type => "shipping")
    @shipping_address.attributes = params[:shipping_address]
    @billing_address = get_user.addresses.build(:address_type => "billing", :email => get_user.email)
  end

  def create_billing
    @billing_address = get_user.addresses.build(:address_type => "billing")
    @billing_address.attributes = params[:billing_address]
    @quote = params[:quote] unless params[:quote].blank?
    new_payment
  end

  def copy_shipping_address
    @billing_address = get_user.addresses.build(get_user.shipping_address.attributes)
    @billing_address.address_type = "billing"
  end

  def forget_credit_card
    get_user.token.delete
    get_user.reload
    @quote = params[:quote] unless params[:quote].blank?
    new_payment
  end

  def change_shipping_method
    @rate = get_cart.shipping_rates.detect {|r| r['type'] == params[:method]}
    get_cart.reset_tax
    get_cart.reset_gift_card
    get_cart.update_attributes :shipping_amount => @rate['rate'], :shipping_service => @rate['type']
  rescue
    calculate_shipping(get_user.shipping_address, :shipping_service => params[:method])
  end

  def get_shipping_options
    return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
    render :partial => 'shipping_options'
  end

  def get_shipping_service
    render :text => get_cart.shipping_service.try(:humanize)
  end

  def get_shipping_amount
    return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
    calculate_shipping(get_user.shipping_address)
    render :inline => "<%= number_to_currency gross_price(get_cart.shipping_amount) %>"
  rescue Shippinglogic::FedEx::Error => e
    render :js => "alert('Unable to calculate shipping rates. please check your shipping address and try again, or call customer service to place an order.');"
  rescue Exception => e
    Rails.logger.error e.backtrace.join("\n")
    render :js => "alert('#{e}');"
  end

  def get_tax_amount
    return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
    render :inline => "<%= number_to_currency calculate_tax(get_user.shipping_address) %>"
  end

  def get_total_amount
    raise 'invalid' unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
    render :inline => "<%= number_to_currency total_cart %>"
  rescue Exception => e
    render :nothing => true, :status => 510
  end

  def get_deferred_first_payment
    raise 'invalid' unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
    @first_payment, @monthly_payment = calculate_setup_fee(get_cart.sub_total, get_cart.shipping_amount + calculate_handling, get_cart.tax_amount)
    render :inline => "<td><%= number_to_currency @first_payment %></td><td><%= number_to_currency @monthly_payment %></td><td><%= number_to_currency @monthly_payment %></td>"
  rescue Exception => e
    render :nothing => true, :status => 510
  end

  def custom_price
    render :nothing => true and return unless current_admin.can_change_prices
    @cart_item = get_cart.cart_items.find(params[:element_id].gsub("cart_item_price_", ""))
    @cart_item.update_attributes(:price => params[:update_value][/[0-9.]+/], :custom_price => true)
    get_cart.reset_tax_and_shipping true
  end

  def set_upsell
    @cart_item = get_cart.cart_items.find(params[:id])
    @cart_item.update_attribute(:upsell, params[:state])
    render :text => @cart_item.upsell
  end

  def activate_coupon
    coupon_code = params[:coupon_code].upcase.gsub(/[^a-zA-Z0-9-]/, '')
    @coupon = Coupon.available.with_coupon.where(:codes.in => [/^#{coupon_code}$/i]).first
    if @coupon
      get_cart.coupon = @coupon
      @cart.coupon_code = coupon_code
      @cart.coupon_updated_at = @coupon.updated_at
      @cart.reset_tax_and_shipping
      @cart.apply_coupon_discount
    else
      render :js => "$('#coupon_form').resetForm();$('#activate_coupon').button({disabled: false});alert('Sorry, the coupon code #{params[:coupon_code]} you entered is invalid. Please check the code and expiration date.');" and return
    end
  end

  def remove_coupon
    get_cart.coupon_id, get_cart.coupon_code, get_cart.coupon_updated_at = nil
    @cart.reset_tax_and_shipping
    @cart.apply_coupon_discount
    render :activate_coupon
  end

  def apply_gift_card
    @payment = Payment.new params[:payment]
    @valutec = Valutec.new :transaction_card_balance, card_number: "#{@payment.full_card_number}=#{@payment.card_pin}"
    if @valutec.response.success? && @valutec.authorized? && params[:balance] != "1" && @valutec.balance > 0.0
      get_cart.update_attributes gift_card_number: @valutec.card_number, gift_card_balance: @valutec.balance
    end
  end

  def remove_gift_card
    get_cart.reset_gift_card
    @cart.save
  end

  def remove_order_reference
    get_cart.update_attribute :order_reference, nil
    render :js => "$('#previous_order_reference').remove();location.href= location.href;"
  end

  def use_previous_orders_card
    new_payment
    render :partial => "payment"
  end

  def shopping_cart
    render :partial => "carts/shopping_cart"
  end

  def save_cod
    if params[:cod_account_type].blank? || params[:cod_account].blank?
      render :js => "alert('COD account type and COD account # fields are required');"
    else
      @user = get_user
      @user.cod_account_type = params[:cod_account_type]
      @user.cod_account = params[:cod_account]
      @user.save(:validate => false)
      get_cart.reset_tax_and_shipping true
      render :action => 'carts/change_shipping_method'
    end
  end

  def cart_upload
    redirect_to(catalog_path) and return unless is_er? && ecommerce_allowed?
  end

  # import cart items from uploaded csv file
  # the following modules have to be compiled for nginx:
  #
  #   NginxHttpUploadProgressModule
  #   nginx_upload_module
  #
  # These directories have to exist and be writable by nginx:
  #
  #   /data/shared/uploads/tmp
  #   /data/shared/uploads/carts
  #
  # change nginx conf:
  #
  # http
  #   upload_progress proxied 1m;
  #
  # server:
  #
  #    # Match this location for the upload module
  #    location /upload/fast_upload {
  #      proxy_pass http://127.0.0.1;
  #      upload_pass @fast_upload_endpoint;
  #      upload_store /data/shared/uploads/tmp;
  #
  #      # set permissions on the uploaded files
  #      upload_store_access user:rw group:rw all:r;
  #
  #      # Set specified fields in request body
  #      # this puts the original filename, new path+filename and content type in the requests params
  #      upload_set_form_field fast_asset[][original_name] "$upload_file_name";
  #      upload_set_form_field fast_asset[][content_type] "$upload_content_type";
  #      upload_set_form_field fast_asset[][filepath] "$upload_tmp_path";
  #
  #      upload_pass_form_field "^X-Progress-ID$|^authenticity_token$";
  #      upload_cleanup 400 404 499 500-505;
  #      track_uploads proxied 30s;
  #      client_max_body_size 100m;
  #    }
  #
  #    location ^~ /progress {
  #      # report uploads tracked in the 'proxied' zone
  #      upload_progress_json_output;
  #      report_uploads proxied;
  #    }
  #
  #    location @fast_upload_endpoint {
  #      passenger_enabled on;
  #      rails_env development;
  #    }
  #
  #    location / {
  #      rails_env development;
  #      passenger_enabled on;
  #    }
  def fast_upload
    redirect_to(catalog_path) and return unless is_er? && ecommerce_allowed?
    #params["fast_asset"] # => [{"original_name"=>"rubymine-1.0.dmg", "content_type"=>"application/x-diskcopy", "filepath"=>"/data/shared/uploads/tmp/0000000004"}]
    if params["fast_asset"].present? && params["fast_asset"].respond_to?('[]')
      params["fast_asset"].each do |item|
        @file = item
        @new_name = "/data/shared/uploads/carts/#{Digest::SHA1.hexdigest("#{@file['original_name']}-#{Time.now.to_f}")}-#{@file['original_name']}"
        FileUtils.mv(item['filepath'], @new_name)
      end

      # check if header columns are correct (item_num, qty)
      header = File.open(@new_name, "r") {|f| f.readline}.gsub(/["\n\r]/,'').split(/,\s*/)
      unless ["item_num", "qty"].all? {|e| header.include?(e)}
        FileUtils.rm_f @new_name
        raise "Uploaded File must have comma separated values, and the header columns must be 'item_num', 'qty' #{header}"
      end
      get_cart.save if get_cart.new_record?
      @cart_importer = CartImporter.create :cart => get_cart, :system => current_system, :file_name => @new_name
      @cart_importer.populate_cart
    else
      raise "No file or invalid file has been uploaded"
    end
  rescue Exception => e
    redirect_to({:action => "cart_upload"}, :alert => e.message)
  end

  def get_cart_import_status
    @cart_importer = CartImporter.find(params[:id])
    render :text => @cart_importer.percent.to_i
  end

  def download_sample_cart_csv
    csv = <<-CSV.strip_heredoc
      "item_num","qty"
      654809,3
      654831,3
      654818,1
      654806,3
      654815,1
      654816,1
      654799,3
      654826,3
      654824,3
      654833,3
      20362-EW,1
      20535-DC,1
      20537-XL,3
      20537-LG,5
      20554-XL,1
      20554-LG,2
      20556-LG,3
      20556-SM,9
      20556-XL,10
      20558-LG,1
    CSV
    send_data csv, :filename => 'cart_itmes.csv', :type => 'text/csv'
  end

  private

  def reset_cart_item_errors
    get_cart.reset_item_errors
  end

  def real_time_cart(quote = false)
    get_cart.update_items true, quote
    flash[:alert] = ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
    # raise RealTimeCartError, ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
    if @cart.cart_errors.present?
      if request.xhr? || params[:format] && params[:format] == 'js'
        response.content_type = Mime::HTML if params[:remotipart_submitted]
        render :js => "window.location.href = '#{cart_path}'" and return false
      else
        redirect_to(cart_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return false
      end
    end
    true
  end

  def add_to_cart_do
    @product = Product.available.find(params[:id])
    qty = params[:qty].blank? ? is_er? ? @product.minimum_quantity : 1 : params[:qty].to_i
    qty = @product.minimum_quantity if is_er? && qty < @product.minimum_quantity
    add_2_cart(@product, qty)
  end

  def remove_from_saved_list
    @list = get_user.save_for_later_list
    @list.product_ids.delete_if {|e| e.to_s == params[:id]}
    @list.save
  end

  def pre_validate_cart
    min_order = if is_er? && user_signed_in? && get_user.orders.count > 0
                  get_user.order_minimum || ER_MIN_ORDER
                elsif is_er? && user_signed_in?
                  get_user.first_order_minimum || ER_FIRST_MIN_ORDER
                else
                  MIN_ORDER
                end
    if get_cart.sub_total < min_order || (is_er? && get_cart.total_weight >= MAX_WEIGHT)
      flash[:alert] = get_cart.sub_total < min_order ?
      "Minimum Order Requirement: There is a #{help.number_to_currency(min_order)} minimum order requirement for online shopping. Please add more products to your shopping cart before checking out."
      : "Cart has reached maximum weight. Please Call Customer Service to place order."
      if request.xhr?
        render :js => "window.location.href = '#{cart_path}'" and return false
      else
        redirect_to(cart_path, :alert => flash[:alert]) and return false
      end
    end
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

end
