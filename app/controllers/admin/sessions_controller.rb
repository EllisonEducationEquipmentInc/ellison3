class Admin::SessionsController < Devise::SessionsController
  ssl_exceptions :destroy
  ssl_allowed :destroy
end