module ApplicationHelper
	
	def system_enabled(object)
		ELLISON_SYSTEMS.inject("") do |buffer, sys|
			checked = instance_eval("@#{object}").try(:systems_enabled).include?(sys) rescue false
			buffer << "#{check_box_tag(object + '[systems_enabled][]', sys, checked)} #{sys}"
		end.html_safe
	end

end
