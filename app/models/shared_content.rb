class SharedContent
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  PLACEMENTS = ["store_locator", "cart", "home", "campaigns", "calendar"]
  
  field :name
  field :active, :type => Boolean, :default => true
  field :short_desc
  field :systems_enabled, :type => Array
  field :placement
  
  scope :active, :where => { :active => true }
  
  index :active
  index :systems_enabled
  index :name
  index :placement
  
  class << self
    PLACEMENTS.each do |e|                                                                                                                   # def store_locator(sys = current_system)
      class_eval "def #{e}(sys = current_system)\n active.where(:systems_enabled.in => [sys], :placement => '#{e}').cache.first \n end"      #   active.where(:systems_enabled.in => [sys], :placement => "store_locator").cache.first
    end                                                                                                                                      # end
  end
  
  validates :name, :systems_enabled, :presence => true
  validates_inclusion_of :placement, :in => PLACEMENTS, :allow_blank => true
  validate :placement_uniqueness, :if => Proc.new {|obj| obj.placement.present?}
  
  references_many :tabs, :index => true, :validate => false
  
  embeds_many :visual_assets do
    
    def billboards
      current.select {|asset| asset.asset_type == "billboard"}
    end
    
    def current
			ordered.select {|asset| asset.available?}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
  
  accepts_nested_attributes_for :visual_assets, :allow_destroy => true , :reject_if => proc { |attributes| attributes['name'].blank? && attributes['systems_enabled'].blank?}
	validates_associated :visual_assets
	
	before_save :run_callbacks_on_children
	
	def products
	  Product.where('tabs.shared_content_id' => self.id)
	end
	
	def ideas
	  Idea.where('tabs.shared_content_id' => self.id)
	end
	
	def destroy
    update_attribute :active, false
  end

private 

  def run_callbacks_on_children
    self.visual_assets.each { |doc| doc.run_callbacks(:save) }
  end

	def placement_uniqueness
	  errors.add(:placement, "already exists for any of these systems: #{self.systems_enabled * ', '}") if self.class.where(:_id.ne => self.id, :placement => self.placement, :systems_enabled.in => self.systems_enabled).count > 0
	end
end
