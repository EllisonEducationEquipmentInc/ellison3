class UsersController < ApplicationController
	prepend_before_filter :require_no_authentication, :only => [ :new, :create, :remote_login]
  prepend_before_filter :authenticate_scope!, :except => [ :new, :create, :checkout_requested, :remote_login, :failure ]
  include Devise::Controllers::InternalHelpers

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
      sign_in_and_redirect(resource_name, resource)
    else
      clean_up_passwords(resource)
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
		@title = "My Account"
		@tabs = [[:billing_info, "My Billing Info"], [:shipping_info, "My Shipping Info"], [:order_status, "Order Status"], [:wishlists, "My List"]]
		@tabs += [[:quotes, "Quotes"], [:materials, "Materials"]] unless is_sizzix?
	end
	
	def billing_info
		render :partial => 'address_info', :locals => {:address_type => "billing"}
	end
	
	def shipping_info
		render :partial => 'address_info', :locals => {:address_type => "shipping"}
	end
	
	def order_status
		render :partial => 'order_status'
	end
	
	def wishlists
		render :partial => 'wishlists'
	end
	
	def quotes
		render :partial => 'quotes'
	end
	
	def materials
		render :partial => 'materials'
	end
	
	def edit_address
		@address = get_user.send("#{params[:address_type]}_address") || get_user.addresses.build(:address_type => params[:address_type])
	end
	
	def update_address
		@address = get_user.send("#{params[:address_type]}_address") || get_user.addresses.build(:address_type => params[:address_type])
		@address.attributes = params["#{params[:address_type]}_address"]
	end
	
	def checkout_requested
		return unless request.xhr?
		session[:user_return_to] = checkout_path
	end
	
	def remote_login   
		params[:email] = 'mronai@ellison.com'
		params[:password] = "mronai"
    resource = warden.authenticate!(:scope => resource_name, :recall => "failure")
		render :js => "alert('success')"
    # set_flash_message :notice, :signed_in 
    #sign_in_and_redirect(resource_name, resource)      
  end     
  
  # Example of JSON response
  # def sign_in_and_redirect(resource_or_scope, resource=nil)
  #   scope      = Devise::Mapping.find_scope!(resource_or_scope)     
  #   resource ||= resource_or_scope
  #   sign_in(scope, resource) unless warden.user(scope) == resource
  #   render :json => { :success => true, :redirect  => stored_location_for(scope) || after_sign_in_path_for(resource) } 
  # end
            
  # JSON login failure message                                                            
  def failure
    #render :json => {:success => false, :errors => {:reason => "Login failed. Try again"}} 
		render :js => "alert('failed')"
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
