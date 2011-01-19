class VisualAsset
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	
	ASSET_TYPES = ["catalog_search", "image", "text", "products", "ideas", "freeform", "gallery", "billboard"]
	
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
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :asset_type
	field :display_order, :type => Integer
	field :images, :type => Array, :default => []
	
	embedded_in :landing_page, :inverse_of => :visual_assets
	embedded_in :shared_content, :inverse_of => :visual_assets
	embedded_in :tag, :inverse_of => :visual_assets
	
	mount_uploader :image, PrivateAttachmentUploader
	
	validates :name, :asset_type, :systems_enabled, :start_date, :end_date, :presence => true
	validates_presence_of :images, :if => Proc.new {|obj| obj.asset_type == "gallery"}
	
  # before_save :force_extract_filename, :if => Proc.new {|obj| obj.asset_type == 'image'}
	
	def display_order
		read_attribute(:display_order) || self._index
	end
	
	def available?(time = Time.zone.now)
		self.start_date <= time && self.end_date >= time && self.active && self.systems_enabled.include?(current_system)
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
	
private

  def force_extract_filename
    # self.class.skip_callback(:save, :after, :extract_filename)

    @image_original_filename = image.instance_variable_get("@original_filename")
    if @image_original_filename.present?
      self.update_attributes :image_filename => @image_original_filename
    end

    # self.class.set_callback(:save, :after, :extract_filename)
  end
	
end
