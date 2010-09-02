class SessionsController < ApplicationController
  prepend_before_filter :require_no_authentication, :only => [ :new, :create ]
  include Devise::Controllers::InternalHelpers

  # GET /resource/sign_in
  def new
    clean_up_passwords(build_resource)
    render_with_scope :new
  end

  # POST /resource/sign_in
  def create
    resource = warden.authenticate!(:scope => resource_name, :recall => request.xhr? ? "failure" : "new")
    set_flash_message :notice, :signed_in
    if request.xhr? 
			sign_in(resource_name, resource)
			render :js => "window.location.href = '#{stored_location_for(:user) || root_path}'" 
		else
			sign_in_and_redirect(resource_name, resource)
		end
  end

  # GET /resource/sign_out
  def destroy
    set_flash_message :notice, :signed_out if signed_in?(resource_name)
    sign_out_and_redirect(resource_name)
  end

  def failure
		render :js => "$('#existing_user_password').attr('value', '');alert('Login failed. Please try again')"
  end
end