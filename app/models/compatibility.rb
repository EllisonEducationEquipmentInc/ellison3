class Compatibility
  include EllisonSystem
  include Mongoid::Document

  field :tag_id, :type => BSON::ObjectId
  field :products, :type => Array, :default => []

  embedded_in :tag, :inverse_of => :compatibilities

  validates_presence_of :tag_id

  def product_item_nums
    read_attribute(:products).try :join, ", "
  end

  def product_item_nums=(product_item_nums)
    write_attribute(:products, product_item_nums.split(/,\s*/)) unless product_item_nums.nil?
  end

  def compatible_tag
    Tag.available.find(self.tag_id) if self.tag_id.present? rescue nil
  end

  def get_products
    Product.displayable.where(:item_num.in => self.products).cache
  end

end
