class UsersController < ApplicationController
	prepend_before_filter :require_no_authentication, :only => [ :new, :create ]
  prepend_before_filter :authenticate_scope!, :only => [:edit, :update, :destroy, :myaccount]
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
		@tabs = %w(my_billing_info my_shipping_info order_status my_list quotes materials)
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
