class UsersController < ApplicationController
	prepend_before_filter :require_no_authentication, :only => [ :new, :create]
  prepend_before_filter :authenticate_scope!, :except => [ :new, :create, :checkout_requested, :signin_signup, :quote_requested, :add_to_list, :save_for_later, :list, :get_lists]
  before_filter :trackable
  include Devise::Controllers::InternalHelpers
  
  ssl_exceptions :signin_signup, :checkout_requested, :quote_requested, :add_to_list, :save_for_later, :list, :get_lists
  ssl_allowed :signin_signup, :checkout_requested, :quote_requested, :add_to_list, :save_for_later, :list, :get_lists

  verify :xhr => true, :only => [:checkout_requested, :quote_requested, :billing, :shipping, :edit_address, :orders, :mylists, :quotes, :materials, :update_list, :create_list, :delete_list, :save_for_later, :add_to_list, :list_set_to_default, :remove_from_list, :move_to_list, :email_list, :view_retailer_application], :redirect_to => {:action => :myaccount}
  verify :post => true, :only => [:create_retailer_application, :order_material]
  
  # GET /resource/sign_up  
  def new
    build_resource({})
    render_with_scope :new
  end

  # POST /resource/sign_up
  def create
    build_resource

    if resource.save
      set_flash_message :notice, :signed_up
      session[:user_return_to] = retailer_application_path if is_er?
			if request.xhr? 
				sign_in(resource_name, resource)
				render :js => "window.location.href = '#{stored_location_for(:user) || root_path}'" 
			else
				sign_in_and_redirect(resource_name, resource)
			end
    else
      clean_up_passwords(resource)
			render :inline => "alert('<%= escape_javascript resource.errors.full_messages.join(\"\n\") %>')" and return if request.xhr? 
      render_with_scope :new
    end
  end

  # GET /resource/edit
  def edit
    redirect_to :action => "myaccount" unless request.xhr?
  end

	# PUT /resource
  def update
    if get_user.update_attributes(params[:user])
			@profile = I18n.t("#{resource_name}.updated", :scope => "devise.#{controller_name}")
      #set_flash_message :profile, :updated
      #redirect_to after_update_path_for(get_user)
    else
      clean_up_passwords(resource)
      render_with_scope :edit
    end
  end

  # DELETE /resource
  def destroy
    get_cart.update_attributes :order_reference => nil if get_cart.order_reference
    resource.destroy
    set_flash_message :notice, :destroyed
    sign_out_and_redirect(self.resource)
  end

	def myaccount
		# get "myaccount/:tab", :to => "users#myaccount"
		# to open a tab from the url, pass the key in the :tab parameter like this: /myaccount/orders or myaccount/mylists or myaccount/quotes etc.
		@title = "My Account - Profile"
    @tabs = []
		@tabs += [[:view_retailer_application, "Your Application"], [:messages, "Messages"]] if is_er?
		@tabs += [[:billing, "My Billing Info"], [:shipping, "My Shipping Info"], [:orders, "Order Status"], [:mylists, "My Lists"], [:machines_i_own, "Machines I own"]]
	  @tabs += [[:quotes, quote_name.pluralize], [:materials, "Materials"]] if is_ee?
	end
	
	def billing
		render :partial => 'address_info', :locals => {:address_type => "billing"}
	end
	
	def shipping
		render :partial => 'address_info', :locals => {:address_type => "shipping"}
	end
	
	def orders
	  @current_locale = current_locale
		@orders = get_user.orders.where(:system => current_system).desc(:created_at).paginate(:page => params[:page], :per_page => 10)
		render :partial => 'order_status'
	end
	
	def order
	  @current_locale = current_locale
		@order = get_user.orders.find params[:id]
		@title = "Order: #{@order.id}"
	rescue
		redirect_to(myaccount_path('orders'))
	end
	
	def messages
	  render :partial => 'messages'
	end
	
	def add_to_list
	  if user_signed_in?
	    if params[:list].blank?
  	    @list = get_user.lists.default || get_user.build_default_mylist	     
	    else
	      @list = get_user.lists.find(params[:list]) rescue get_user.build_default_mylist	
	    end
	    @list.add_product params[:id]
	  else
	    @message = I18n.t :list_not_logged_in
	  end
	end
	
	def save_for_later
	  if user_signed_in?
      @list = get_user.save_for_later_list
	    @list.add_product get_cart.cart_items.find_item(params[:item_num]).product_id
      @cart_item_id = remove_cart(params[:item_num])
	  else
	    @message = I18n.t :save_for_later_not_logged_in
	  end
	end
	
	def get_lists
	  if user_signed_in?
  	  @lists = get_user.lists.listable
  	  @lists << get_user.build_default_mylist if @lists.blank? || (@lists.length == 1 && @lists.first.owns)
  	  @lists = @lists.map {|e| ["#{e.name} #{' (default)' if e.default_list}", e.id]}
  	  render :partial => 'lists'
  	else
  	  @message = I18n.t :list_not_logged_in
	    render :add_to_list
  	end
	end
	
	def remove_from_list
	  @list = get_user.lists.find params[:list]
	  @list.product_ids.delete_if {|e| e.to_s == params[:id]}
	  @list.save
	end
	
	def move_to_list
	  raise "Item cannot be moved to the same list" if params[:list] == params[:move_to]
	  @list = get_user.lists.find params[:list]
	  @new_list = get_user.lists.find params[:move_to]
	  @list.product_ids.delete_if {|e| e.to_s == params[:id]}
	  @list.save
	  @new_list.add_product params[:id]
	  render :remove_from_list
	rescue Exception => e
		render :js => "alert(\"#{e.message}\")"
	end
	
	def list
		@list = List.find params[:id]
		@users_list = user_signed_in? && get_user.lists.include?(@list)
		@lists = user_signed_in? && get_user.lists.listable.map {|e| [e.name, e.id]}
		@title = "List: #{@list.name}"
	rescue
		redirect_to(myaccount_path('mylists'))
	end
	
	def create_list
	  @list = List.new params[:list]
	  @list.user = current_user
	  @list.save!
	  get_user.list_set_to_default(@list.id.to_s) if @list.default_list || get_user.lists.default.blank?
	rescue Exception => e
		render :js => "alert(\"#{e.message}\")"
	end
	
	def delete_list
	  @list = get_user.lists.find params[:id]
	  @list.delete
	  render :js => "$('#list_row_#{@list.id}').remove()"
	end
	
	def email_list
	  @list = get_user.lists.find params[:id]
	  if @list && !params[:list_to].blank? && !params[:list_your_name].blank? && params[:list_to].split(/,\s*/).all? {|e| e =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/}
	    UserMailer.email_list(get_user, params[:list_your_name], params[:list_to].split(/,\s*/), @list, params[:list_note]).deliver
	  else
	    raise "Unable to send email. Please make sure that you have specified Your name and entered a valid recipient email address."
	  end
	  render :js => "$('#email_list_form').resetForm();$.fancybox.close();alert('Your email has been sent to: #{params[:list_to]}')"
	rescue Exception => e
		render :js => "alert('#{e.message}')"
	end
	
	def update_list
    attribute, id = params[:element_id].split("_")
	  @list = get_user.lists.find id
	  @list.update_attributes attribute => params[:update_value]
	  render :text => params[:update_value]
	end
	
	def list_set_to_default
	  get_user.list_set_to_default(params[:id])
	  render :nothing => true
	rescue Exception => e
		render :js => "alert(\"#{e.message}\")"
	end
	
	def quotes
	  @current_locale = current_locale
		@quotes = get_user.quotes.active.where(:system => current_system).desc(:created_at).paginate(:page => params[:page], :per_page => 10)
		render :partial => 'quotes'
	end
	
	def quote
	  @current_locale = current_locale
		@quote = get_user.quotes.active.where(:system => current_system, :_id => BSON::ObjectId(params[:id])).first
		@title = "#{quote_name}: #{@quote.id}"
		@billing_address = get_user.addresses.build(:address_type => "billing", :email => get_user.email) if get_user.billing_address.blank?
		update_user_token
		new_payment
  rescue
    redirect_to(myaccount_path('quotes'))
	end
	
	def mylists
	  get_user.create_owns_list if get_user.lists.owns.blank?
	  @lists = get_user.lists.listable
		render :partial => 'mylists'
	end
	
	def materials
	  @material_order = MaterialOrder.new
	  @material_order.address = get_user.shipping_address || Address.new
		render :partial => 'materials'
	end
	
	def view_retailer_application
	  @user = get_user
	  render :partial => "view_retailer_application"
	end
	
	def edit_address
		@address = get_user.send("#{params[:address_type]}_address") || get_user.addresses.build(:address_type => params[:address_type], :email => get_user.email)
	end
	
	def update_address
		@checkout = params[:checkout]
		@address = get_user.send("#{params[:address_type]}_address") || get_user.addresses.build(:address_type => params[:address_type])
		@address.attributes = params["#{params[:address_type]}_address"]
		set_vat_exempt
		get_cart.reset_tax_and_shipping(true) if @address.address_type == 'shipping'
	end
	
	def signin_signup
		redirect_to(new_session_path('user', :secure => true)) and return unless request.xhr?
	  render :partial => "login_or_checkout", :layout => false
	end
	
	def checkout_requested
		session[:user_return_to] = checkout_path(:secure => true)
	end
	
	def quote_requested
	  session[:user_return_to] = get_cart.pre_order? ? pre_order_path(:secure => true) : quote_path(:secure => true)
	  render :checkout_requested
	end
	
	def retailer_application
	  @title = "Ellison Retailer Application"
	  @user = get_user
	  @user.build_retailer_application unless @user.retailer_application
    @user.build_addresses("billing", "shipping", "home")
	end
	
	def create_retailer_application
	  @user = get_user
	  @user.attributes = params[:user]
	  @user.build_retailer_application unless @user.retailer_application
	  @user.build_addresses("billing", "shipping", "home")
	  @user.retailer_application.attributes = params[:user][:retailer_application]
	  @user.tax_exempt_certificate ||= @user.retailer_application.resale_number
	  if @user.save
	    @user.retailer_application.save
	    redirect_to(myaccount_path, :notice => 'Thank you for submitting your application as an Authorized Ellison Retailer. Your request is currently being processed and is pending approval. While we confirm your information, please take a tour of the website. However, please remember that your special pricing can only be accessed once your application has been approved. Thanks for your patience, and we look forward to serving you.')
	  else
	    render :retailer_application
	  end
	end
	
	def machines_i_own
	  render :partial => 'users/machines_poll'
	end
	
	def order_material
	  @material_order = MaterialOrder.new(params[:material_order])
	  @material_order.user = get_user
	end
	
	def eclipsware
	  @text = SystemSetting.value_at("firmware_text") || SystemSetting.new(:key => "firmware_text").value
	  @title = "eclips Software"
	end
	
	def show_fw_files
	  if FirmwareRange.valid? params[:serial_number]
	    @files = Firmware.active.asc(:created_at)
	    cookies[:serial_number] = { :value => params[:serial_number], :expires => 1.hour.from_now }
	  else
	    render :js => "alert('Invalid Serial Number');"
	  end
	end
	
	def download_firmware
	  @firmware = Firmware.find(params[:id])
	  redirect_to :action => "eclipsware" and return unless cookies[:serial_number] && @firmware
	  unless File.exists? "/data/shared/firmware_files/#{@firmware.id}"
	    @gridfs_file = Mongo::GridFileSystem.new(Mongoid.database).open(@firmware.file_url.gsub(/^\/grid\//,''), 'r')
	    File.open("/data/shared/firmware_files/#{@firmware.id}", "wb") {|file| file.write(@gridfs_file.read)}
	  end
	  send_file "/data/shared/firmware_files/#{@firmware.id}", :filename => @firmware.file_filename
	end
	
protected

  # Authenticates the current scope and gets a copy of the current resource.
  # We need to use a copy because we don't want actions like update changing
  # the current user in place.
  def authenticate_scope!
    send(:"authenticate_#{resource_name}!")
    self.resource = resource_class.find(send(:get_user).id)
  end
  
end
