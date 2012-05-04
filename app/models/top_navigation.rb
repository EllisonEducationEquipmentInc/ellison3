require 'singleton'

class TopNavigation
  include Singleton 
  include EllisonSystem
  
  Navigation = Struct.new(:label, :link, :css_class)
  
  def initialize
    list
  end
  
  def list(sys = current_system)
    send "list_#{sys}"
  end

private

  # define top navigation values for each system here:
  def list_szus
    [
      Navigation.new("Project Gallery", "/lp/categories?ideas=1"), 
      Navigation.new("Shop", "/catalog"), 
      Navigation.new("eclips", "/shop/eclips"),
      Navigation.new("Quilting", "/shop/sizzixquilting"),
      Navigation.new("Community", "#"),
      Navigation.new("Clearance", "/shop/clearance", "nav_clearance")
    ]
  end
  
  def list_szuk
    [
      Navigation.new("Products", "/catalog"), 
      Navigation.new("Quilting", "#"),
      Navigation.new("Projects", "/lp/categories?ideas=1"), 
      Navigation.new("Promotions", "/campaigns"),
      Navigation.new("Featured", "#"),
      Navigation.new("Community", "#"),
      Navigation.new("Support", "#")
    ]
  end
  
  def list_eeus
    [
      Navigation.new("Lessons", "/lp/curriculums?ideas=1"), 
      Navigation.new("Products", "/product_overview"), 
      Navigation.new("Electronic Cutting", "/eclips"),
      Navigation.new("Specials", "/campaigns"),
      Navigation.new("Support", "#")
    ]
  end
  
  def list_eeuk
    [
      Navigation.new("Lessons", "/lp/categories?ideas=1"), 
      Navigation.new("Products", "/catalog"), 
      Navigation.new("News & Events", "/events"),
      Navigation.new("About Us", "/aboutus")
    ]
  end
  
  def list_er
    [
      Navigation.new("Craft Products", "/shop/sizzixcrafting"), 
      Navigation.new("Craft Projects", "/shop/sizzixcrafting"), 
      Navigation.new("Education Products", "/shop/ellisoneducation"),
      Navigation.new("Education Projects", "/shop/ellisoneducation"),
      Navigation.new("Community", "#"),
      Navigation.new("Support", "#")      
    ]
  end
  
  alias :list_erus :list_er
  alias :list_eruk :list_er
  
  
  
end
