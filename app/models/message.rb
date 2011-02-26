class Message
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :active, :type => Boolean, :default => true
	field :subject
	field :body
	field :discount_levels, :type => Array
	field :created_by
	
  referenced_in :user, :validate => false

  scope :active, :where => { :active => true }
  scope :group_message, :where => { :discount_levels.exists=> true, :user_id  => nil }
  
  index :discount_levels
  index :active
  
  def destroy
    update_attribute :active, false
  end
  
  def discount_levels=(levels)
    write_attribute :discount_levels, levels.map {|e| e.to_i} if levels.is_a? Array
  end
end
