class Admin::SessionsController < Devise::SessionsController
  before_filter :set_admin_title
  ssl_exceptions :destroy
  ssl_allowed :destroy
end