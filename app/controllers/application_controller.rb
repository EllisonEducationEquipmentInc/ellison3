class ApplicationController < ActionController::Base
  protect_from_forgery
	
	before_filter :get_system
	
  layout :get_layout

	helper_method :vat, :gross_price, :calculate_vat

private
	
	# TODO: CMS for this
	def vat
		@vat ||= SystemSetting.value_at("vat").to_f
	end
	
	def gross_price(price, vat_exempt = false)
    sess = session[:vat_exempt] rescue vat_exempt
    if is_us? || sess || vat_exempt
      price
    else
      (price.to_f * (1+vat/100.0)).round(2)
    end
  end
  
  def calculate_vat(price, vat_exempt = false)
    sess = session[:vat_exempt] rescue vat_exempt
    if is_us? || sess || vat_exempt
      0.0
    else
      (price.to_f * (vat/100.0)).round(2)
    end
  end

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
	
	def go_404
		render :file => "#{Rails.root}/public/404_#{current_system}.html", :layout => false, :status => 404
	end
end
