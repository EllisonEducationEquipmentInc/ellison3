class Navigation
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
  
  NAVIGATION_TYPES = ["product_tag", "idea_tag", "static"]
  
  field :active, :type => Boolean, :default => true
  field :label
  field :link
  field :tag_type
  field :navigation_type
  field :system, :default => lambda {current_system}
  field :top_nav, :type => Integer
  field :column, :type => Integer
  
	field :created_by
	field :updated_by
	
	embeds_many :navigation_links do
	  def ordered
      @target.sort {|x,y| x.display_order <=> y.display_order}
    end

    def resort!(ids)
      @target.each {|t| t.display_order = ids.index(t.id.to_s)}
    end
	end
	
	accepts_nested_attributes_for :navigation_links, :allow_destroy => true, :reject_if => proc { |attributes| attributes['label'].blank?}
	
	index :system
	index :top_nav
	index :column
	
	before_save :set_system
	
	validates_presence_of :label, :navigation_type, :system, :top_nav, :column
	validates_numericality_of :top_nav, :column, :only_integer => true, :greater_than_or_equal_to => 0
	validates_inclusion_of :navigation_type, :in => NAVIGATION_TYPES
	validates_inclusion_of :system, :in => ELLISON_SYSTEMS
	validates_inclusion_of :tag_type, :in => Tag::TYPES, :if => Proc.new {|obj| ["product_tag", "idea_tag"].include? obj.navigation_type}

private
  
  def set_system
    self.system ||= current_system
  end
end