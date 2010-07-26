module EllisonSystem  
	
	ELLISON_SYSTEMS = %w(szus szuk eeus eeuk er)
  LOCALES = %w(en-US en-UK en-EU)

	def current_system
		@current_system ||= "szus"
	end
	
	def current_system=(s)
		@current_system = s if ELLISON_SYSTEMS.include?(s)
		set_default_locale
		@current_system
	end
	
	def set_current_system(s)
		self.current_system = s
	end
	
	def current_locale
		@current_locale ||= "en-US"
	end
	
	def current_locale=(l)
		@current_locale = l if LOCALES.include?(l)
	end
	
	def set_current_locale(l)
		self.current_locale = l
	end
  
  def is_er?
    # is ellison_retailers?
    current_system == 'er'
  end
  
  def is_ee?
    # is ellison_education?
    current_system == 'eeus' || current_system == 'eeuk'
  end
  
  def is_sizzix?
    current_system == "szus" || current_system == "szuk"
  end
  
  def is_us?
    current_locale == 'en-US'
  end
  
  def is_uk?
    current_locale == 'en-UK' || current_locale == 'en-EU'
  end
    
  def is_sizzix_us?
    is_sizzix? && is_us?
  end
  
  def is_sizzix_uk?
    is_sizzix? && is_uk?
  end
  
  def is_ee_us?
    is_ee? && is_us?
  end
  
  def is_ee_uk?
    is_ee? && is_uk?
  end
  
  def order_prefix
    current_system.upcase
  end
  
  def get_domain
    if is_er? 
      "ellison.com"
    elsif is_ee?
      "ellisoneducation.#{is_us? ? 'com' : 'co.uk'}"
    else
      "sizzix.#{is_us? ? 'com' : 'co.uk'}"
    end
  end

	# EY app names
	def app_name
		if is_sizzix_us?
      "sizzix_2_us"
		elsif is_sizzix_uk?
			"sizzix_2_uk"
    elsif is_ee_us?
      "ellison_education"
		elsif is_ee_uk?
			"ellison_education_uk"
    elsif is_er?
      "ellison_global"
    end
	end
	
	def set_default_locale
		if %w(szus eeus er).include?(current_system) && current_locale != "en-US"
			set_current_locale "en-US"
		elsif %w(szuk eeuk).include?(current_system) && current_locale == "en-US"
			set_current_locale "en-UK"
		end
		[@current_system, @current_locale]
	end
	
end

class ActiveRecord::Base
  include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActionView::Base
  include EllisonSystem
end

class ActionMailer::Base
  include EllisonSystem
end

class ActionController::Base
  include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActiveRecord::Migration
	include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActionController::IntegrationTest
	include EllisonSystem
  class << self
    include EllisonSystem
  end
end