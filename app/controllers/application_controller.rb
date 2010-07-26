class ApplicationController < ActionController::Base
  protect_from_forgery
	
	before_filter :get_system
	
  layout :get_layout

private

	def get_system
		unless RAILS_ENV == 'production'
			session[:system] = params[:system] if params[:system]
			set_current_system(session[:system])
		end
	end
	
	def get_layout
		if is_sizzix_us?
			'application'
		elsif is_sizzix_uk?
			'application_szuk'
		elsif is_ee?
			'application_ee'
		else
			'application_er'
		end
	end
end
