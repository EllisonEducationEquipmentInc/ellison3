class SharedContent
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Associations::EmbeddedCallbacks
  
  field :name
  field :active, :type => Boolean, :default => true
  field :short_desc
  field :systems_enabled, :type => Array
  
  scope :active, :where => { :active => true }
  
  index :active
  index :systems_enabled
  index :name
  
  validates :name, :systems_enabled, :presence => true
  
  references_many :tabs, :index => true
  
  embeds_many :visual_assets do
    def current
			ordered.select {|asset| asset.available?} #.sort {|x,y| x.display_order <=> y.display_order}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
  
  accepts_nested_attributes_for :visual_assets, :allow_destroy => true, :reject_if => proc { |attributes| attributes['name'].blank?}
	validates_associated :visual_assets
	
	def products
	  Product.where('tabs.shared_content_id' => self.id)
	end
	
	def ideas
	  Idea.where('tabs.shared_content_id' => self.id)
	end
end
