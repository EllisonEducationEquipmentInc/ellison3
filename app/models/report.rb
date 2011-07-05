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
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
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
		@campaigns = Order.send self.report_type, campaign
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
