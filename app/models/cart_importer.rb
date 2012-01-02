class CartImporter
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :file_name
  field :complete, :type => Boolean, :default => false
  field :percent, :type => Integer, :default => 0
  field :total_count, :type => Integer, :default => 0
  field :system
  field :import_errors, :type => Array, :default => []
  
  belongs_to :cart
  
  validates_presence_of :file_name, :cart_id
  
  def initialize(attrs = nil)
    super
    set_current_system self.system || current_system
    self.total_count = File.readlines(file_name).count
  end
  
  def populate_cart
    n = 0
    CSV.foreach(self.file_name, :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      product = Product.available.where(:item_num => row['item_num'].upcase).first
      unless product.present? && product.orderable? && product.can_be_added_to_cart?
        update_attribute :import_errors, self.import_errors << row['item_num']
        next
      end
      qty = row['item_num'].blank? ? is_er? ? product.minimum_quantity : 1 : row['qty'].to_i
      qty = product.minimum_quantity if is_er? && qty < product.minimum_quantity
      if item = self.cart.cart_items.find_item(product.item_num)
        item.quantity += qty
        self.cart.save
      else
        self.cart.cart_items << CartItem.new(:name => product.name, :item_num => product.item_num, :sale_price => product.outlet? ? product.price : product.sale_price, :msrp => product.msrp_or_wholesale_price, :price => product.price, 
          :quantity => qty, :currency => current_currency, :small_image => product.small_image, :added_at => Time.now, :product => product, :weight => product.virtual_weight, :actual_weight => product.weight, :retailer_price => product.retailer_price,
          :tax_exempt => product.tax_exempt, :handling_price => product.handling_price, :pre_order => product.pre_order?, :out_of_stock => product.out_of_stock?, :minimum_quantity => product.minimum_quantity, :campaign_name => product.campaign_name, :outlet => product.outlet?)
      end
      n += 1
      percentage!(n)
    end
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

private

  def modulo
    m = self.total_count/10
    case 
    when m < 2
      2
    when m > 50
      50
    else
      m
    end
  end

  def percentage!(n)
    update_attribute(:percent, (n.to_f)/total_count*100) if n%modulo==0
  end

  def completed!
    self.complete = true
    self.percent = 100
    save!
    FileUtils.rm_f self.file_name
  end  
end
