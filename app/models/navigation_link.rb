class NavigationLink
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :label
  field :link
  field :display_order, :type => Integer
  
  embedded_in :navigation, :inverse_of => :navigation_links
  
  def display_order
		read_attribute(:display_order) || self._index
	end
end