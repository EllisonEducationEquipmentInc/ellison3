class ApplicationController < ActionController::Base
  protect_from_forgery
	
	before_filter :get_system
	
  layout :get_layout

private

	def get_system
		domain_to_system(request.host)
		unless Rails.env == 'production'
			session[:system] = params[:system] if params[:system]
			set_current_system(session[:system])
		end
	end
	
	def set_locale
		if I18n.available_locales.include?(params[:locale])
			
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
