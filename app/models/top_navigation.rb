require 'singleton'

class TopNavigation
  include Singleton 
  include EllisonSystem
  
  Navigation = Struct.new(:label, :link)
  
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
      Navigation.new("Projects", "/lp/categories?ideas=1"), 
      Navigation.new("New & Notable", "/catalog#ideas=1"), 
      Navigation.new("Machines & Accessories", "lp/categories"),
      Navigation.new("Products", "/catalog"),
      Navigation.new("Electronic Cutting", "/shop/eclips"),
      Navigation.new("Clearance", "/outlet")
    ]
  end
  
  def list_szuk
    [
      Navigation.new("Products", "/catalog"), 
      Navigation.new("Projects", "/lp/categories?ideas=1"), 
      Navigation.new("Promotions", "/campaigns"),
      Navigation.new("Featured", "#"),
      Navigation.new("Community", "#"),
      Navigation.new("Support", "#")
    ]
  end
  
  def list_eeus
    [
      Navigation.new("Lessons", "/lp/categories?ideas=1"), 
      Navigation.new("Products", "/catalog"), 
      Navigation.new("Electronic Cutting", "/shop/eclips"),
      Navigation.new("Specials", "/campaigns"),
      Navigation.new("Community", "#"),
      Navigation.new("Support", "#")
    ]
  end
  
  def list_eeuk
    [
      Navigation.new("Lessons", "/lp/categories?ideas=1"), 
      Navigation.new("Products", "/catalog"), 
      Navigation.new("Specials", "/campaigns"),
      Navigation.new("Community", "#"),
      Navigation.new("Support", "#")
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