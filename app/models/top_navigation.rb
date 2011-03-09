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
      Navigation.new("Projects", "/catalog#ideas=1"), 
      Navigation.new("New & Notable", "/catalog#ideas=1"), 
      Navigation.new("Machines & Accessories", "/catalog#facets=category~machines-accessories"),
      Navigation.new("Products", "/catalog"),
      Navigation.new("Electronic Cutting", "/shop/eclips"),
      Navigation.new("Clearance", "/outlet")
    ]
  end
  
  def list_szuk
    [
      Navigation.new("Sizzix Products", "/catalog"), 
      Navigation.new("Craft Projects", "/catalog#ideas=1"), 
      Navigation.new("Promotions", "/campaigns"),
      Navigation.new("Featured", "#"),
      Navigation.new("Support", "/contact")
    ]
  end
  
  def list_eeus
    [
      Navigation.new("Lessons", "/catalog#ideas=1"), 
      Navigation.new("Products", "/catalog"), 
      Navigation.new("Electronic Cutting", "/shop/eclips"),
      Navigation.new("Specials", "/campaigns"),
      Navigation.new("Support", "/contact")
    ]
  end
  
  def list_eeuk
    [
      Navigation.new("Lessons", "/catalog#ideas=1"), 
      Navigation.new("Products", "/catalog"), 
      Navigation.new("Electronic Cutting", "/shop/eclips"),
      Navigation.new("Specials", "/campaigns"),
      Navigation.new("Support", "/contact")
    ]
  end
  
  def list_er
    [
      Navigation.new("Sizzix Crafts", "/shop/crafts"), 
      Navigation.new("Ellison Education", "/shop/education"), 
      Navigation.new("Support", "/contact"),
      Navigation.new("My Account", "/myaccount")
    ]
  end
  
  alias :list_erus :list_er
  alias :list_eruk :list_er
  
  
  
end