class Cart
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :tax_amount, :type => Float
  field :tax_transaction
  field :tax_calculated_at, :type => DateTime
  field :shipping_calculated_at, :type => DateTime
  field :shipping_rates, :type => Array
  field :shipping_service
  field :shipping_amount, :type => Float
  field :removed, :type => Integer, :default => 0
  field :removed_items, :type => Array, :default => []
  field :coupon_removed, :type => Boolean, :default => false
  field :coupon_has_been_updated, :type => Boolean, :default => false
  field :changed_items, :type => Array
  field :order_reference
  field :coupon_code
  field :coupon_updated_at, :type => DateTime
  field :free_shipping_by_coupon, :type => Boolean, :default => false
  field :last_check_at, :type => DateTime
  field :gift_card_number
  field :gift_card_balance, type: Float

  referenced_in :coupon

  embeds_many :cart_items do
    def find_item(item_num)
      @target.detect {|item| item.item_num == item_num}
    end
  end

  def clear
    destroy
  end

  def reset_tax
    self.tax_amount, self.tax_transaction, self.tax_calculated_at = nil
  end

  def reset_shipping_amount
    self.free_shipping_by_coupon = false
    self.shipping_amount, self.shipping_service, self.shipping_rates, self.shipping_calculated_at = nil
  end

  def reset_gift_card
    self.gift_card_balance, self.gift_card_number = nil
  end

  def reset_tax_and_shipping(to_save = false)
    reset_gift_card
    reset_shipping_amount
    reset_tax
    save if to_save
  end

  def reset_item_errors
    update_attributes :removed => 0, :changed_items => nil, :coupon_removed => false
  end

  def sub_total(excluded_items = [])
    cart_items.reject {|e| excluded_items.include? e.item_num}.inject(0) {|sum, item| sum += item.total}
  end

  def total_weight(excluded_items = [])
    cart_items.reject {|e| excluded_items.include? e.item_num}.inject(0) {|sum, item| sum += (item.quantity * item.weight)}.round(2)
  end

  def total_actual_weight
    cart_items.inject(0) {|sum, item| sum += (item.quantity * item.actual_weight)}.round(2)
  end

  def total_volume
    cart_items.inject(0) {|sum, item| sum += (item.quantity * item.volume)}
  end

  def total_quantity
    cart_items.inject(0) {|sum, item| sum += item.quantity}
  end

  def taxable_amaunt
    cart_items.select {|i| !i.tax_exempt}.inject(0) {|sum, item| sum += item.total}
  end

  def handling_amount
    cart_items.inject(0) {|sum, item| sum += (item.quantity * item.handling_price)}
  end

  def total
    (sub_total + tax_amount + shipping_amount + handling_amount).round(2)
  end

  def gift_card_applied_amount
    return 0.0 unless gift_card_number && gift_card_balance && gift_card_balance > 0.0
    if gift_card_balance > total
      total
    else
      gift_card_balance
    end
  rescue
    0.0
  end

  def gift_card_applied?
    gift_card_applied_amount > 0.0
  end

  def balance_due
    total - gift_card_applied_amount
  end

  def pre_order?
    cart_items.any? {|e| e.pre_order}
  end

  def out_of_stock?
    cart_items.any? {|e| e.out_of_stock}
  end

  # if cart qualifies for deferred payments
  def allow_deferred?
    is_sizzix_us? && sub_total < 1000.01 && cart_items.any? {|o| o.eclips?}
  end

  def changed_item_attributes
    self.changed_items.map {|e| e[1]}.flatten.uniq rescue nil
  end

  def cart_errors
    @cart_errors = []
    @cart_errors << "The cart can only contain 99 items per order." if !is_er? && total_quantity > MAX_ITEMS
    @cart_errors << "The maximum amount in the cart per order is 100,000" if sub_total > MAX_CART_VALUE
    @cart_errors << "Your shopping cart contains one or more Gift Cards. Gift Cards must be ordered separately from other items. Please remove items that cannot be ordered together and proceed to checkout. Remember, Gift Card orders ship for FREE!" unless cart_items.all?(&:gift_card) || cart_items.none?(&:gift_card)
    if self.changed_items.present? || self.removed > 0 || self.coupon_removed #|| self.coupon_has_been_updated
      @cart_errors << "The price on one or more of the items in your order has been adjusted since you last placed it in your Shopping Cart. Items in your cart will always reflect the most recent price displayed on their corresponding product detail pages." if changed_item_attributes.include?("price")
      @cart_errors << "Some items placed in your cart are greater than the quantity available for sale. The most current quantity available has been updated in your Shopping Cart." if changed_item_attributes.include?("quantity")
      @cart_errors << "Stock level of some items placed in your cart has changed." if changed_item_attributes.include?("out_of_stock")
      @cart_errors << "Availability of some items placed in your cart has changed." if changed_item_attributes.include?("pre_order")
      @cart_errors << "Items #{self.removed_items * ', '} placed in your Shopping Cart are no longer available for purchase and have been removed. If you are still interested in this item(s), please check back again at a later date for availability." if self.removed > 0
      @cart_errors << "The Handling price on one or more of the items in your order has been adjusted since you last placed it in your Shopping Cart." if changed_item_attributes.include?("handling_price")
      @cart_errors << "Your coupon is no longer valid or changed. Please review your Shopping Cart to verify its contents." if self.coupon_removed
      #@cart_errors << "Your coupon has changed. Please review your Shopping Cart to verify its contents." if self.coupon_has_been_updated
      # TODO: min qty, handling amount
      #"The quantity of some items placed in your cart is less than the required minimum quantity. The required minimum quantity has been updated in your Shopping Cart."
    end
    @cart_errors
  end

  def is_cart_item_changed?(cart_item_id, item_attribute)
    self.changed_items.detect {|i| i[0] == cart_item_id}[1].include? item_attribute
  rescue
    false
  end

  def gift_card?
    cart_items.any? &:gift_card
  end

  # to adjust qty and remove unavailable items and prompt user, pass true in the argument
  def update_items(check = false, quote = false, country = nil)
    return if cart_items.blank?
    Rails.logger.info "Cart: cart items are being updated"
    if check && cart_items.any?(&:coupon_price)
      reset_coupon_items
      save
    end
    self.removed = 0
    self.removed_items = []
    self.changed_items = nil
    cart_items.each do |item|
      next if item.coupon?
      product = item.product
      item.write_attributes :sale_price => product.outlet? ? product.price : product.sale_price, :campaign_name => product.campaign_name, :msrp => product.msrp_or_wholesale_price, :currency => current_currency, :small_image => product.small_image, :tax_exempt => product.tax_exempt, :outlet => product.outlet?, :pre_order => product.pre_order?,
      :handling_price => product.handling_price, :gift_card => product.gift_card, :retailer_price => product.retailer_price, :weight => product.virtual_weight(current_system, country), :actual_weight => product.weight, :out_of_stock => backorder_allowed? && product.listable?(current_system, item.quantity) ? product.out_of_stock?(current_system, item.quantity - 1) : product.out_of_stock?
      item.price = product.price unless item.custom_price
      if check
        if quote && !product.available?
          item.quantity = 0
          #elsif (quote && can_place_quote_on_backordered? || backorder_allowed?) && product.out_of_stock? && product.listable?
          # do nothing
        elsif (quote && can_place_quote_on_backordered? || backorder_allowed?) && product.listable?(current_system, item.quantity) && product.quantity < item.quantity
          # mark item as "out_of_stock" to trigger limited quantity notification
          item.out_of_stock = true
          item.reset_attribute! "out_of_stock" if item.changes["out_of_stock"].present? && item.changes["out_of_stock"].uniq.count == 1
        else
          Rails.logger.info "Cart: removing item..."
          item.quantity = product.unavailable? ? 0 : product.quantity if product.unavailable? || product.quantity < item.quantity
        end
      end
    end
    if check
      self.removed_items = cart_items.where(:quantity.lt => 1).map {|e| e.item_num}
      self.removed = cart_items.delete_all(:conditions => {:quantity.lt => 1})
      self.changed_items = cart_items.select(&:updated?).map {|i| [i.id, i.updated]}
      self.coupon = Coupon.available.with_coupon.where(:_id => self.coupon_id).first
      self.coupon_id = Coupon.available.with_coupon.where(:_id => self.coupon_id).first.try :id #lame!
      self.coupon_removed = self.changed.include? "coupon_id"
      self.coupon_code, self.coupon_updated_at = nil if self.coupon_removed
      #self.coupon_has_been_updated = self.coupon_updated_at != self.coupon.try(:updated_at)
      self.last_check_at = Time.now.utc
    end
    reset_tax_and_shipping if cart_items.any?(&:updated?) || self.removed > 0 || self.coupon_removed #|| self.coupon_updated_at != self.coupon.try(:updated_at)
    #self.coupon_updated_at = self.coupon.try(:updated_at) if self.coupon_updated_at != self.coupon.try(:updated_at)
    apply_coupon_discount
  end


  # coupon discount applied here
  def apply_coupon_discount
    reset_coupon_items
    if !coupon.blank? && coupon_conditions_met?
      if coupon.product?
        cart_items.where(:item_num.in => coupon.products).each do |item|
          item.calculate_coupon_discount(coupon)
        end
      elsif coupon.group?
        coupon.children.select {|c| coupon_conditions_met?(c)}.each do |child|
          cart_items.where(:item_num.in => child.products).each do |item|
            item.calculate_coupon_discount(child)
          end
        end
      elsif coupon.order?
        # === if order level coupon is a line item:
        # order_discount = coupon.percent? ? (0.01 * coupon.discount_value * sub_total(coupon.products_excluded + [Coupon::COUPON_ITEM_NUM])).round(2) : coupon.discount_value
        # cart_items << CartItem.new(:name => coupon.name, :item_num => Coupon::COUPON_ITEM_NUM, :msrp => -(order_discount), :price => -(order_discount), :coupon_price => true,
        #  :quantity => 1, :currency => current_currency, :small_image => nil, :added_at => Time.now, :product_id => nil, :weight => 0, :tax_exempt => false, :handling_price => 0, :volume => 0)

        # === if order level discount is distributed:
        cart_items.where(:item_num.nin => coupon.products_excluded).each do |item|
          item.calculate_coupon_discount(coupon)
        end
      elsif coupon.highest_priced_product?
        item = cart_items.where(:item_num.nin => coupon.products_excluded).order_by(:price.desc).first
        item.calculate_coupon_discount(coupon) if item
      end
    end
    save
  end

  def coupon_conditions_met?(c = coupon)
    return false if !c.cart_must_have.blank? && !c.cart_must_have.all? do |condition|
      condition.flatten[1].send("#{condition.flatten[0]}?") {|i| cart_items.map(&:item_num).include?(i)}
    end
    c.order_has_to_be && c.order_has_to_be.each do |key, conditions|
      return false unless conditions.all? {|e| e[1].to_f.send(e[0].to_sym == :over ? "<" : ">", send(key, c.products_excluded))}
    end
    true
  end

  def shipping_conditions_met?(address, c = coupon)
    c.shipping_countries.include?(address.country) && ((address.us? && c.shipping_states.include?(address.state)) || !address.us?)
  end

  def reset_coupon_items
    cart_items.find_item(Coupon::COUPON_ITEM_NUM).try :delete
    cart_items.select {|i| i.coupon_price}.each {|i| i.write_attributes(:coupon_name => nil, :coupon_price => false, :price => i.sale_price || (is_er? ? i.retailer_price : i.msrp))}
  end

  def cod?
    self.shipping_service == "COD"
  end

  def total_discount
    cart_items.inject(0) {|sum, item| sum += (item.msrp * item.quantity)} - sub_total
  end
end
