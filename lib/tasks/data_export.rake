namespace :data_export do
  
  # example:
  #    rake data_export:google_atom system=eeus
  desc "exports product to google atom feed"
	task :google_atom => :environment do
	  set_current_system ENV['system'] || "szus"
		include ActionView::Helpers::AtomFeedHelper
		new_relic_wrapper "google_atom" do
    
  		PATH = Rails.env == 'development' ? Rails.root : "/data/shared/cron"
  		File.open("#{PATH}/#{current_system}_product_feed.xml", "w") do |file|
  			xml = Builder::XmlMarkup.new(:target=>file, :indent=>2)
  			atom_feed({:xml => xml, :id => "tag:#{get_domain},2005:/admin/products/google_feed", :root_url => "http://#{get_domain}/", :url => "http://#{get_domain}/admin/products/google_feed.atom",
  				 						'xmlns' => 'http://www.w3.org/2005/Atom', 'xmlns:g' => 'http://base.google.com/ns/1.0'}) do |feed|
  			  feed.title("#{current_system}_product_feed.xml")
  			  feed.updated(Time.zone.now)
  				Product.listable.in_batches(100) do |group|
  				  group.each do |product|
							print "."
					    feed.entry(product, :id => product.id, :url => "http://www.#{get_domain}/product/#{product.item_num}/#{product.name.parameterize}") do |entry|
					      entry.title(product.name)
					      entry.description(product.description)
								entry.tag!("g:image_link", "http://www.#{get_domain}#{product.medium_image}")
								entry.tag!("g:price", gross_price(product.price))
								entry.tag!("g:condition", "new")
								entry.tag!("g:product_type", "Arts & Entertainment > Crafts & Hobbies > Scrapbooking")
								entry.tag!("g:brand", is_sizzix? ? "Sizzix" : "Ellison") 
								#entry.tag!("g:id", product.item_num)
								entry.tag!("g:upc", product.upc) unless product.upc.blank?
								entry.tag!("g:mpn", product.item_num)
					    end
  				  end
  				end
  			end
  		end
  		p ''
  		p "exporting #{current_system} products to #{current_system}_product_feed.xml has completed"
  	end
	end
	
	def gross_price(price)
	  if is_us?
      price
    else
      @vat ||= SystemSetting.value_at("vat").to_f
      (price.to_f * (1+@vat/100.0)).round(2)
    end
	end
	
	desc "creates pre orders report in /data/shared/report_files/"
	task :pre_orders_report => :environment do
	  new_relic_wrapper "pre_orders_report" do
  	  set_current_system ENV['system'] || "erus"
      FileUtils.mkdir "/data/shared/report_files" unless File.exists? "/data/shared/report_files"
      filename = "pre_orders_report_#{current_system}_#{Time.now.utc.strftime "%m%d%Y_%H%M"}.csv"
      csv_string = CSV.generate do |csv|
        csv << ["item_num", "quantity", "item_total"]
        Quote.pre_orders_report.each do |item|
          csv << [item["_id"], item["value"]["quantity"], item["value"]["item_total"]]
        end
      end
      File.open("/data/shared/report_files/#{filename}", "w") {|file| file.write(csv_string)}
      p "/data/shared/report_files/#{filename} is ready"
    end
	end
	
	desc "reindex all products"
	task :reindex_products => :environment do
	  new_relic_wrapper "reindex_products" do
	    p "Total: #{Product.active.count}"
	    b,i = 0,0
	    Product.active.in_batches(500) do |batch|
	      p "--- batch: #{b+=1} #{batch.inspect} #{batch.size}"
        batch.each do |product|
          product.delay.index rescue next
          p "#{i+=1} #{product.item_num}"
        end
      end
      Sunspot.delay.commit
	  end
	end
	
	desc "reindex all ideas"
	task :reindex_ideas => :environment do
	  new_relic_wrapper "reindex_ideas" do
	    p "Total: #{Idea.active.count}"
	    b,i = 0,0
	    Idea.active.in_batches(500) do |batch|
	      p "--- batch: #{b+=1} #{batch.inspect} #{batch.size}"
        batch.each do |idea|
          idea.delay.index rescue next
          p "#{i+=1} #{idea.idea_num}"
        end
      end
      Sunspot.delay.commit
	  end
	end
	
	desc "export_all_products"
	task :export_all_products => :environment do
	  CSV.open("/data/shared/report_files/all_products_report_#{Digest::SHA1.hexdigest("#{Time.now.to_f}")}.csv", "w") do |csv|
      csv << [Time.zone.now]
      csv << ["id", "upc", "item_num", "name", "systems_enabled"] + WAREHOUSES.map {|e| "quantity_#{e}"} + ELLISON_SYSTEMS.map {|e| "orderable_#{e}"} + ELLISON_SYSTEMS.map {|e| "start_date_#{e}"} + ELLISON_SYSTEMS.map {|e| "end_date_#{e}"} + ELLISON_SYSTEMS.map {|e| "distribution_life_cycle_#{e}"} + ELLISON_SYSTEMS.map {|e| "distribution_life_cycle_ends_#{e}"} + LOCALES_2_CURRENCIES.values.map {|e| "msrp_#{e}"} + LOCALES_2_CURRENCIES.values.map {|e| "wholesale_price_#{e}"} + LOCALES_2_CURRENCIES.values.map {|e| "handling_price_#{e}"} + ["msrp", "sale_price", "life_cycle", "active", "short_desc", "long_desc", "keywords", "outlet", "minimum_quantity", "discount_category", "item_type", "item_group", "tags", "video"]
      csv << header
      Product.limit(10).in_batches(500) do |batch|
        batch.each do |product|
        end
      end
    end
	end

end