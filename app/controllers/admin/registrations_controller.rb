class Admin::RegistrationsController < Devise::RegistrationsController
  before_filter :set_admin_title
  #ssl_exceptions
  
  def create
    build_resource

    if resource.save
      set_flash_message :notice, :signed_up
      redirect_to after_sign_in_path_for(resource)
    else
      clean_up_passwords(resource)
      render_with_scope :new
    end
  end
end
