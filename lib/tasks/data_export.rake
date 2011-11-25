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
          Product.listable.orderable.in_batches(100) do |group|
            group.each do |product|
              next if product.google_availability.blank?
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
                entry.tag!("g:availability", product.google_availability)
                entry.tag!("g:google_product_category", "Arts & Entertainment > Crafts & Hobbies > Scrapbooking")
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
    CSV.open("/data/shared/report_files/all_products_report_#{Time.now.strftime "%m%d%Y_%H%M"}.csv", "w") do |csv|
      csv << [Time.zone.now]
      csv << ["id", "upc", "item_num", "name", "systems_enabled"] + WAREHOUSES.map {|e| "quantity_#{e}"} + ELLISON_SYSTEMS.map {|e| "orderable_#{e}"} + ELLISON_SYSTEMS.map {|e| "availability_message_#{e}"} + ELLISON_SYSTEMS.map {|e| "start_date_#{e}"} + 
            ELLISON_SYSTEMS.map {|e| "end_date_#{e}"} + ELLISON_SYSTEMS.map {|e| "distribution_life_cycle_#{e}"} + ELLISON_SYSTEMS.map {|e| "distribution_life_cycle_ends_#{e}"} + 
            LOCALES_2_CURRENCIES.values.map {|e| "msrp_#{e}"} + LOCALES_2_CURRENCIES.values.map {|e| "wholesale_price_#{e}"} + LOCALES_2_CURRENCIES.values.map {|e| "handling_price_#{e}"} + ELLISON_SYSTEMS.map {|s| LOCALES_2_CURRENCIES.values.map {|e| "price_#{s}_#{e}"}}.flatten +
            ["life_cycle", "active",  "keywords", "outlet", "minimum_quantity", "discount_category", "item_type", "item_group", "video", "instructions", "tags"]
      Product.all.in_batches(500) do |batch|
        batch.each do |product|
          prices = []
          ELLISON_SYSTEMS.each do |s| 
            set_current_system s
            LOCALES_2_CURRENCIES.keys.each do |e|
              I18n.locale = e
              prices << (product.price rescue 'N/A')
            end
          end
          csv << [product.id, product.upc, product.item_num, product.name, product.systems_enabled * ', '] + WAREHOUSES.map {|e| product.send("quantity_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("orderable_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("availability_message_#{e}")} + 
                 ELLISON_SYSTEMS.map {|e| product.send("start_date_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("end_date_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("distribution_life_cycle_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("distribution_life_cycle_ends_#{e}")} + 
                 LOCALES_2_CURRENCIES.values.map {|e| product.send("msrp_#{e}")} + LOCALES_2_CURRENCIES.values.map {|e| product.send("wholesale_price_#{e}")} + LOCALES_2_CURRENCIES.values.map {|e| product.send("handling_price_#{e}")} + prices +
                 [product.life_cycle, product.active, product.keywords, product.outlet, product.minimum_quantity, product.discount_category.try(:name), product.item_type, product.item_group, product.video, product.instructions, product.tags.order([:tag_type, :asc]).map {|e| "#{e.name} - (#{e.tag_type})"} * ', ']
        end
      end
    end
  end
  
  desc "export_all_ideas"
  task :export_all_ideas => :environment do
    CSV.open("/data/shared/report_files/all_ideas_report_#{Time.now.strftime "%m%d%Y_%H%M"}.csv", "w") do |csv|
      csv << [Time.zone.now]
      csv << ["id", "idea_num", "name", "systems_enabled"] + ELLISON_SYSTEMS.map {|e| "start_date_#{e}"} + ELLISON_SYSTEMS.map {|e| "end_date_#{e}"} + ELLISON_SYSTEMS.map {|e| "distribution_life_cycle_#{e}"} + ELLISON_SYSTEMS.map {|e| "distribution_life_cycle_ends_#{e}"} +  ["objective", "active", "keywords", "item_group", "video", "tags"] 
      Idea.all.in_batches(500) do |batch|
        batch.each do |product|
          csv << [product.id, product.idea_num, product.name, product.systems_enabled * ', '] + ELLISON_SYSTEMS.map {|e| product.send("start_date_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("end_date_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("distribution_life_cycle_#{e}")} + ELLISON_SYSTEMS.map {|e| product.send("distribution_life_cycle_ends_#{e}")} + 
                 [product.objective, product.active, product.keywords, product.item_group, product.video, product.tags.order([:tag_type, :asc]).map {|e| "#{e.name} - (#{e.tag_type})"} * ', '] 
        end
      end
    end
  end
  

end