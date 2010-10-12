module AdminHelper
  
  def admin_systems_checkboxes
    r = ''
    admin_systems.each do |sys|
      r << check_box_tag("systems_enabled[]", sys, params[:systems_enabled] && params[:systems_enabled].include?(sys), :id => nil)
      r << sys
    end
    r.html_safe
  end
  
  
end
