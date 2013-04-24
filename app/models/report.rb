class Report
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :file_name
  field :complete, :type => Boolean, :default => false
  field :percent, :type => Integer, :default => 0
  field :total_count, :type => Integer, :default => 0
  field :report_type
  field :report_options, :type => Hash, :default => {}
  field :start_date, :type => Time
  field :end_date, :type => Time
  field :system

  validates_presence_of :file_name

  def initialize(attrs = nil)
    super
    set_current_system self.system || current_system
    self.file_name ||= "reports/#{id}/#{Digest::SHA1.hexdigest("#{id}-#{Time.now.to_f}")}.csv"
  end

  def order_analysis
    set_current_system self.system || current_system
    self.report_type = "order_analysis"
    @orders = Order.send(current_system).not_cancelled.where(:created_at.gt => self.start_date, :created_at.lt => self.end_date).desc(:created_at)
    self.total_count = @orders.count
    n = 0
    csv_string = CSV.generate  do |csv|
      csv << ["order_number", "order creation date", "customer email address", "customer profile creation date", "total_amount", "clickid", "utm_source", "cookie"]
      @orders.each do |order|
        n += 1
        percentage!(n)
        csv << [order.public_order_number, order.created_at, order.user.email, order.user.created_at, order.total_amount, order.clickid, order.utm_source, order.tracking]
      end
    end
    write_to_gridfs csv_string
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

  def campaign_coupon_usage(campaign, report_type = "campaign")
    set_current_system self.system || current_system
    self.report_type = "#{report_type}_usage"
    @campaigns = Order.send self.report_type, campaign, :start_date => self.start_date, :end_date => self.end_date
    self.total_count = @campaigns.count
    n = 0
    csv_string = CSV.generate  do |csv|
      csv << ["item_num", "name", "number_of_orders", "quantity", "quoted_price", "sale_price", "item_total", "locale"]
      @campaigns.each do |item|
        n += 1
        percentage!(n)
        csv << [item["_id"]["item_num"], item["_id"]["name"], item["value"]["number_of_orders"], item["value"]["quantity"], item["_id"]["quoted_price"], item["_id"]["sale_price"], item["value"]["item_total"], item["_id"]["locale"]]
      end
    end
    write_to_gridfs csv_string
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

  def shipping_coupon_usage(coupon)
    set_current_system self.system || current_system
    self.report_type = "shipping_coupon_usage"
    @campaigns = Order.shipping_coupon_usage coupon
    self.total_count = @campaigns.count
    n = 0
    csv_string = CSV.generate  do |csv|
      csv << ["locale", "number_of_orders", "total_subtotal_amount", "total_shipping", "total_line_items"]
      @campaigns.each do |item|
        n += 1
        percentage!(n)
        csv << [item["_id"], item["value"]["number_of_orders"], item["value"]["total_subtotal_amount"], item["value"]["total_shipping"], item["value"]["total_line_items"]]
      end
    end
    write_to_gridfs csv_string
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

  def product_performance(tag)
    set_current_system self.system || current_system
    self.report_type = "product_performance"
    @items = Order.product_performance tag, :start_date => self.start_date, :end_date => self.end_date
    self.total_count = @items.count
    n = 0
    csv_string = CSV.generate  do |csv|
      csv << ["item_num", "name", "number_of_orders", "quantity", "quoted_price", "sale_price", "item_total", "locale", "outlet"]
      @items.each do |item|
        n += 1
        percentage!(n)
        csv << [item["_id"]["item_num"], item["_id"]["name"], item["value"]["number_of_orders"], item["value"]["quantity"], item["_id"]["quoted_price"], item["_id"]["sale_price"], item["value"]["item_total"], item["_id"]["locale"], item["_id"]["outlet"]]
      end
    end
    write_to_gridfs csv_string
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

  def customer_report(tag)
    set_current_system self.system || current_system
    self.report_type = "customer_report"
    @users = User.where(:_id.in => Order.send(self.system).not_cancelled.where(:created_at.gt => self.start_date, :created_at.lt => self.end_date, :"order_items.product_id".in => tag.product_ids).distinct(:user_id).compact)
    self.total_count = @users.count
    n = 0
    csv_string = CSV.generate  do |csv|
      csv << ["email", "company", "first_name", "last_name", "last_sign_in_at"]
      @users.each do |user|
        n += 1
        percentage!(n)
        csv << [user.email, user.company, user.billing_address.try(:first_name), user.billing_address.try(:last_name), user.last_sign_in_at]
      end
    end
    write_to_gridfs csv_string
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

  def active_quotes_report
    set_current_system self.system || current_system
    self.report_type = "active_quotes_report"
    @quotes = Quote.send(current_system).active.where(:created_at.gt => self.start_date, :created_at.lt => self.end_date)
    self.total_count = @quotes.count
    n = 0
    csv_string = CSV.generate do |csv|
      csv << ["quote_number", "quote name", "item_num", "name","release_dates", "quoted_price", "sales_price", "quantity", "campaign_name", "coupon_code", "created_at", "expires_at", "customer_rep", "company", "name", "email", "erp", "subtotal", "shipping_amount", "handling_amount", "sales_tax", "total_amount", "total_discount", ]
      @quotes.each do |quote|
        quote.order_items.each do |item|
          csv << [item.quote.quote_number, item.quote.name, item.item_num, item.name, item.product.tags.release_dates.map(&:name) * ', ', item.quoted_price, item.sale_price, item.quantity, item.campaign_name,  item.quote.coupon_code, item.quote.created_at, item.quote.expires_at, item.quote.get_customer_rep.try(:email), item.quote.user.company, item.quote.user.name, item.quote.user.email, item.quote.user.erp, item.quote.subtotal_amount, item.quote.shipping_amount, item.quote.handling_amount, item.quote.tax_amount, item.quote.total_amount, item.quote.total_discount ]
        end
      end
    end
    write_to_gridfs csv_string
    completed!
  rescue Exception => e
    Rails.logger.error("#{e}")
  end

  def real_time_stock_status_reports
    set_current_system self.system || current_system
    self.report_type = "real_time_stock_status_reports"
    @products = Product.send(current_system).active
    @products = @products.where(:outlet => report_options["outlet"].present?) if report_options["outlet"].present?
    @products = @products.where(:"orderable_#{self.system}" => report_options["orderable"].present?) #if report_options["orderable"].present?
    @products = @products.where(item_group: report_options["item_group"]) if report_options["item_group"].present?
    @products = @products.where(life_cycle: report_options["life_cycle"]) if report_options["life_cycle"].present?
    self.total_count = @products.count
    n = 0
    csv_string = CSV.generate do |csv|
      csv << ["Item #", "Item Name", "Lifecycle", "Brand", "Orderable", "Price", "Qty US", "Qty SZ", "Qty UK","Outlet"]
      @products.in_batches(500) do |batch|
        batch.each do |product|
          csv << [product.item_num, product.name, product.life_cycle, product.item_group, product.orderable?, product.price, product.quantity_us, product.quantity_sz, product.quantity_uk,product.outlet]
        end
      end
    end
    write_to_gridfs csv_string
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
    Rails.logger.info("--- #{self.file_name} report completed")
  end

  def write_to_gridfs(data)
    Mongo::GridFileSystem.new(Mongoid.database).open(file_name, 'w') do |gridfs_file|
      gridfs_file.write data
    end
  end
end
