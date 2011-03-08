class VisualAsset
  include EllisonSystem
	include Mongoid::Document
		
	ASSET_TYPES = ["catalog_search", "image", "products", "ideas", "freeform", "image_with_text"]
	CHILD_ASSET_TYPES = ["gallery", "billboard"]
	PARENT_ASSET_TYPES = ["galleries", "billboards"]
	
	field :name
	field :systems_enabled, :type => Array
	field :short_desc
  field :content
  field :link
  field :search_query
  field :item_limit, :type => Integer, :default => 12
  field :products, :type => Array
	field :ideas, :type => Array
	field :active, :type => Boolean, :default => true
	field :wide, :type => Boolean, :default => false
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :asset_type
	field :display_order, :type => Integer
	field :images, :type => Array, :default => []
	field :recurring, :type => Boolean, :default => false
	field :must_own, :type => Array
	
	Date::DAYNAMES.each do |day|
	  field :"#{day.downcase}", :type => Boolean, :default => false
	end
	
	recursively_embeds_many
	accepts_nested_attributes_for :child_visual_assets, :allow_destroy => true, :reject_if => proc { |attributes| attributes['name'].blank? && attributes['systems_enabled'].blank?}
	
	embedded_in :landing_page, :inverse_of => :visual_assets
	embedded_in :shared_content, :inverse_of => :visual_assets
	embedded_in :tag, :inverse_of => :visual_assets
	
	mount_uploader :image, PrivateAttachmentUploader
	
	validates :name, :asset_type, :systems_enabled, :start_date, :end_date, :presence => true
  
  before_save :run_callbacks_on_children, :if => Proc.new {|obj| obj.asset_type == 'billboards' || obj.asset_type == 'galleries'}
	
	def initialize(attributes = nil)
	  super
	  self.start_date ||= 1.month.ago
	  self.end_date ||= 10.years.since
	end

	def display_order
		read_attribute(:display_order) || self._index
	end
	
	def available?(time = Time.zone.now)
		self.start_date <= time && self.end_date >= time && self.active && self.systems_enabled.include?(current_system) && (!self.recurring || self.recurring && self.send(time.strftime("%A").downcase))
	end
	
	def product_item_nums
		read_attribute(:products).try :join, ", "
	end
	
	def product_item_nums=(product_item_nums)
		write_attribute(:products, product_item_nums.split(/,\s*/)) unless product_item_nums.nil?
	end
	
	def idea_idea_nums
		read_attribute(:ideas).try :join, ", "
	end
	
	def idea_idea_nums=(idea_idea_nums)
		write_attribute(:ideas, idea_idea_nums.split(/,\s*/)) unless idea_idea_nums.nil?
	end
	
	def wide?
	  shared_content.present? && shared_content.respond_to?(:placement) && shared_content.placement.present?
	end
	
	def is_child?
	  parent_visual_asset.present?
	end
	
	def asset_types_list
	   is_child? ? CHILD_ASSET_TYPES : ASSET_TYPES + PARENT_ASSET_TYPES
	end
	
private

  def run_callbacks_on_children
    self.child_visual_assets.select {|obj| obj.asset_type == 'billboard' || obj.asset_type == 'gallery'}.each { |doc| doc.run_callbacks(:save) } if self.child_visual_assets.present?
  end
	
end
