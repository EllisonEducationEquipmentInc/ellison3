require File.expand_path(File.dirname(__FILE__) + '/../../lib/ax.rb')

namespace :ax do
  
  desc "create dirs"
  task :create_dirs => :include_ax do
    ['to_ax', 'from_ax', 'processed_ax', 'uk_to_ax'].each do |dir|
		  FileUtils.mkdir "#{PATH}/#{dir}" unless File.exists? "#{PATH}/#{dir}"
		end
		FileUtils.mkdir "#{PATH}/to_ax/pre_orders" unless File.exists? "#{PATH}/to_ax/pre_orders"
  end
  
  desc "create ax xml from open US orders"
  task :orders_to_ax => :include_ax do
    new_relic_wrapper "orders_to_ax" do
      @orders = Order.where(:status => "Open", :system.in => ["szus", "eeus", "erus"])
    
      if @orders.count > 0
        xml = build_ax_xml @orders
        filename = "global_orders_download_#{Time.now.strftime("%d%m%y_%H%M%S")}.xml"
        File.open("#{PATH}/to_ax/#{filename}", "w") { |f| f.puts(xml)}
        @orders.update_all(:status => "Processing")
        p "#{filename} has been created"
      else
        p "there are no open orders in the system"
      end
    end
  end
  
  desc "create ax xml from open UK orders"
  task :uk_orders_to_ax => :include_ax do
    new_relic_wrapper "uk_orders_to_ax" do
      @orders = Order.where(:status => "Open", :system.in => ["szuk", "eeuk"])
    
      if @orders.count > 0
        xml = build_ax_xml @orders
        filename = "global_orders_download_#{Time.now.strftime("%d%m%y_%H%M%S")}.xml"
        File.open("#{PATH}/uk_to_ax/#{filename}", "w") { |f| f.puts(xml)}
        @orders.update_all(:status => "Processing")
        p "#{filename} has been created"
      else
        p "there are no open orders in the system"
      end
    end
  end
  
  desc "create ax xml from off hold US orders"
  task :paid_pre_orders_to_ax => :include_ax do
    new_relic_wrapper "paid_pre_orders_to_ax" do
      @orders = Order.where(:status => "Off Hold", :system.in => ["szus", "eeus", "erus"])
    
      if @orders.count > 0
        xml = build_ax_xml @orders
        filename = "paid_pre_orders_download_#{Time.now.strftime("%d%m%y_%H%M%S")}.xml"
        File.open("#{PATH}/to_ax/pre_orders/#{filename}", "w") { |f| f.puts(xml)}
        @orders.update_all(:status => "Processing")
        p "#{filename} has been created"
      else
        p "there are no open orders in the system"
      end
    end
  end
  
  desc "process order status updates from AX"
  task :status_update => :include_ax do
    new_relic_wrapper "status_update" do
      Dir.glob("#{PATH}/from_ax/orders_status_update_*") do |filename| 
        result = order_status_update(IO.read(filename))
        if result == 1
          FileUtils.mv filename, "#{PATH}/processed_ax/"
          p "#{filename} has been successfully proccessed"
        else
          p result
        end
      end
    end
  end
  
  desc "update inventory on-hand quantities from AX inventory xml"
  task :inventory_update => :include_ax do
    new_relic_wrapper "inventory_update" do
      options = {:exclude => ENV['exclude']}
      Dir.glob("#{PATH}/from_ax/inventory_upload_*") do |filename| 
        result = update_inventory_from_ax(IO.read(filename), options)
        if result == 1
          FileUtils.mv filename, "#{PATH}/processed_ax/"
          p "#{filename} has been successfully proccessed"
        else
          p result
        end
      end
    end
  end
  
  desc "CCH commit from invoice_tax.xml"
  task :commit_cch => :include_ax do
    new_relic_wrapper "commit_cch" do
      Dir.glob("#{PATH}/from_ax/invoice_tax*") do |filename| 
      
        doc = REXML::Document.new(IO.read(filename))
        doc.root.elements.each('orders') do |orders|
  	      orders.elements.each('order') do |order|
  	        tax_transaction_id, order_number = order.attributes['tax_trans_id'], order.attributes['order_number']
  	        print "processing #{order_number} \t\t\t"
            begin
              @cch = CCH::Cch.new(:action => 'commit', :transaction_id => tax_transaction_id)
            rescue Timeout::Error => e
              sleep(5)
              print "#{e} \t\t retrying...\t"
              retry
            rescue Exception => e
              print "#{e} \n"
              next
            end
            if @cch.success?
              print "done\n"
              Order.find_by_public_order_number(order_number).try(:update_attribute, :tax_committed, true)
            else
              print "ERROR: #{@cch.errors}\n"
            end
          end
        end
        FileUtils.mv filename, "#{PATH}/processed_ax/"
        p "#{filename} has been successfully proccessed"
      end
    end
  end
  
  
  desc "creates ax status update xml (FOR TEST PURPOSES ONLY, IT IS DONE BY AX)"
  task :create_status_update_xml => :include_ax do
    new_relic_wrapper "create_status_update_xml" do
    
      order_status = ENV['order_status'] || "Processing"
      change_to = ENV['change_to'] || 'In Process'
      @orders =  Order.where(:status => order_status)
      if @orders.count > 0
        xml = create_status_update_xml @orders, :state => change_to
        filename = "orders_status_update_#{Time.now.strftime("%d%m%y_%H%M%S")}.xml"
        File.open("#{PATH}/from_ax/#{filename}", "w") { |f| f.puts(xml)}
        p "#{filename} has been created"
      else
        p "there are no #{order_status} orders in the system"
      end
    end
  end
  
  desc "fix fedex tracking url's"
  task :fix_fedex => :include_ax do
    orders = Order.shipped.all(:conditions => ["tracking_url LIKE ?","%www.fedex.com/Tracking?cntry_code=us%"])
    orders.each do |order|
      order.update_attribute(:tracking_url, "http://www.fedex.com/Tracking?ascend_header=1&clienttype=dotcom&cntry_code=us&language=english&tracknumbers=#{order.tracking_number}")
      p "#{order.order_number}:  #{order.tracking_url}"
    end
  end
  
  desc "include AX"
  task :include_ax => :environment do
    include Ax
    include ShoppingCart
    Ax.module_eval { include(EllisonSystem) }
  end
  
  desc "create order status update xml (FOR TEST PURPOSES ONLY)"
  task :create_inventory_update_xml => :include_ax do
    xml = Builder::XmlMarkup.new(:indent => 2)
    xml.instruct!
    xml.inventory_update do
      xml.items do 
        Product.active.limit(10).each do |product|
          onhand_qty_wh11 = rand(100)
          onhand_qty_wh01 = rand(100)
          onhand_qty_uk = rand(100)
          xml.item(:number => product.item_num, :onhand_qty => onhand_qty_wh11 + onhand_qty_wh01, :onhand_qty_wh01 => onhand_qty_wh01, :onhand_qty_wh11 => onhand_qty_wh11, :onhand_qty_uk => onhand_qty_uk, :life_cycle_date => Time.now.strftime("%m/%d/%y"), :life_cycle => random_life_cycle)
        end
      end
    end
    filename = "inventory_upload_#{Time.now.strftime("%d%m%y_%H%M%S")}.xml"
    File.open("#{PATH}/from_ax/#{filename}", "w") {|file| file.puts(xml.target!)}
    p "#{PATH}/from_ax/#{filename} has been created" 
  end

  def random_life_cycle
    case rand 10
    when 9
      "Inactive"
    when 8
      "Discontinued"
    when 7
      "Pre-Release"
    when 6
      ''
    else
      "Active"
    end
  end
  
end