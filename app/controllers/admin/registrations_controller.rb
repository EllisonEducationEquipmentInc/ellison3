class Admin::RegistrationsController < Devise::RegistrationsController
  before_filter :set_admin_title
  ssl_exceptions
end