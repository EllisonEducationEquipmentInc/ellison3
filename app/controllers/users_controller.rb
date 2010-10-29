class UsersController < ApplicationController
	prepend_before_filter :require_no_authentication, :only => [ :new, :create]
  prepend_before_filter :authenticate_scope!, :except => [ :new, :create, :checkout_requested, :signin_signup, :quote_requested]
  before_filter :trackable
  include Devise::Controllers::InternalHelpers
  
  ssl_exceptions :signin_signup, :checkout_requested, :quote_requested
  ssl_allowed :signin_signup, :checkout_requested, :quote_requested

  verify :xhr => true, :only => [:checkout_requested, :quote_requested, :billing, :shipping, :edit_address, :orders, :mylists, :quotes, :materials], :redirect_to => {:action => :myaccount}

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
    resource.destroy
    set_flash_message :notice, :destroyed
    sign_out_and_redirect(self.resource)
  end

	def myaccount
		# get "myaccount/:tab", :to => "users#myaccount"
		# to open a tab from the url, pass the key in the :tab parameter like this: /myaccount/orders or myaccount/mylists or myaccount/quotes etc.
		@title = "My Account - Profile"
		@tabs = [[:billing, "My Billing Info"], [:shipping, "My Shipping Info"], [:orders, "Order Status"], [:mylists, "My List"]]
		@tabs += [[:quotes, quote_name.pluralize], [:materials, "Materials"]] unless is_sizzix?
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
		new_payment
  rescue
    redirect_to(myaccount_path('quotes'))
	end
	
	def mylists
		render :partial => 'mylists'
	end
	
	def materials
		render :partial => 'materials'
	end
	
	def edit_address
		@address = get_user.send("#{params[:address_type]}_address") || get_user.addresses.build(:address_type => params[:address_type], :email => get_user.email)
	end
	
	def update_address
		@checkout = params[:checkout]
		@address = get_user.send("#{params[:address_type]}_address") || get_user.addresses.build(:address_type => params[:address_type])
		@address.attributes = params["#{params[:address_type]}_address"]
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
	  session[:user_return_to] = quote_path(:secure => true)
	  render :checkout_requested
	end
	
private

	def new_payment
		@payment = Payment.new
		@payment.attributes = get_user.billing_address.attributes if get_user.billing_address
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
