# encoding: utf-8
namespace :data_migrations do
  require "active_record/railtie"  
  
  desc "test"
  task :test => [:set_szuk, :load_dep]  do
    set_current_system "szuk"
    product = OldData::Product.find 2259
    p product.availability_msg
    p OldData::Product.send "is_uk?"
  end
  
  desc "migrate tags"
  task :tags => :load_dep do
    OldData::PolymorphicTag.not_deleted.all(:conditions => ["tag_type NOT IN (?)", [1,16]]).each do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      new_tag = Tag.new :old_id => tag.id, :name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => ["szus", "szuk", "er"], :description => tag.short_desc, :start_date_szus => tag.start_date, :all_day => tag.all_day, :color => tag.color,
        :end_date_szus => tag.end_date, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image, :calendar_start_date_szus => tag.calendar_start_date, :calendar_end_date_szus => tag.calendar_end_date, :keywords => tag.keywords
      print new_tag.save
      p tag.id
    end
  end
  
  desc "migrate SZUS products"
  task :products_szus => :load_dep do
    OldData::Product.not_deleted.find_each do |product|
      #product = OldData::Product.find 102 #2011 #67
      new_product = Product.new :name => product.name, :description_szus => product.short_desc, :old_id => product.id, :systems_enabled => ["szus"], :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :active => product.new_active_status, 
        :outlet => product.clearance, :outlet_since => product.outlet_since, :life_cycle => product.new_life_cycle, :orderable_szus => product.new_orderable, :msrp_usd => product.msrp, :keywords => product.keywords, :start_date_szus => product.start_date, :end_date_szus => product.end_date, 
        :quantity_us => product.quantity, :distribution_life_cycle_szus => product.life_cycle, :distribution_life_cycle_ends_szus => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_szus => product.availability_msg
      new_product.price = product.price if new_product.outlet
      new_product.tags = Tag.where(:old_id.in => product.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_product.save
      ["image2", "image3", "embelish_image", "line_drawing", "zoom_image"].each do |meth|
        unless product.send(meth).blank?
          image = new_product.images.build
          begin
            image.remote_image_url = "http://www.sizzix.com/images/#{product.send(meth)}"
            p image.save
          rescue Exception => e
            p e.message
          end        
        end
      end
      p new_product.save
      p new_product.errors
      next unless new_product.valid?
      new_product.reload
      new_product.tags = Tag.where(:old_id.in => product.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_product.save
      p new_product.errors
      p "------ #{product.id} -------"
    end
    p Sunspot.commit
  end
  
  desc "migrate SZUS product tabs"
  task :tabs_szus => :load_dep do
    Product.all.each do |product|
      #product = Product.find '4cf847fbe1b8326863000227'
      old_product = OldData::Product.find(product.old_id) rescue next
      old_product.tabs.not_deleted.each do |tab|
        next if product.tabs.where(:name => tab.name).count > 0
        new_tab = product.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["szus", "szuk", "er"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
    p Sunspot.commit
  end
    
  def process_tab(tab,new_tab,sys="sz")
    unless tab.column_grid.blank?
      new_tab.data_column ||= []
      for i in 1..OldData::Tab::MAX_GRID do
        new_tab.data_column << [tab.column_grid["left_#{i}"][0], tab.column_grid["left_#{i}"][1]] unless tab.column_grid["left_#{i}"].blank?
        new_tab.data_column << [tab.column_grid["right_#{i}"][0], tab.column_grid["right_#{i}"][1]] unless tab.column_grid["right_#{i}"].blank?
      end
    end
    unless tab.item_nums.blank?
      unless tab.item_nums[:compatibility].blank?
        new_tab.compatibility = []
        tab.item_nums[:compatibility].each do |comp|
          next if comp.all? {|e| e.blank?}
          # TODO: sort by original order
          new_tab.compatibility << OldData::Product.all(:select => "item_num", :conditions => ["id IN (?)", comp.reject {|e| e.blank?}]).map {|e| e.item_num}
        end
      end
      new_tab.products = OldData::Product.all(:select => "item_num", :conditions => ["id IN (?)", tab.item_nums[:products].compact.uniq]).map {|e| e.item_num} unless tab.item_nums[:products].blank?
      new_tab.ideas = OldData::Idea.all(:conditions => ["id IN (?)", tab.item_nums[:ideas].compact.uniq]).map {|e| e.idea_num.to_s} unless tab.item_nums[:ideas].blank?
    end
    unless tab.images.blank? || tab.images["large_images"].blank?
      p "found images"
      new_tab.save
      i=0
      tab.images["large_images"].reject {|e| e.blank?}.each do |img|
        image = new_tab.images.build
        p image.caption = tab.images["captions"][i]
        begin
          p image.remote_image_url = "http://www.#{sys == 'edu' ? "ellisoneducation" : "sizzix"}.com/images/#{img}"
          p image.save
        rescue Exception => e
          p e.message
        ensure
          i+=1
        end
      end
    end
  end
  
  desc "migrate sizzix ideas"
  task :ideas_sz => :load_dep do
    #idea = OldData::Idea.find 1820
    OldData::Idea.find_each do |idea|
      new_idea = Idea.new :name => idea.name, :description_szus => idea.short_desc, :old_id => idea.id, :systems_enabled => ["szus", "szuk", "er"], :idea_num => idea.idea_num.to_s, :long_desc => idea.long_desc, :active => idea.active_status, 
         :keywords => idea.keywords, :start_date_szus => idea.start_date, :end_date_szus => idea.end_date, :objective => idea.objective,
         :distribution_life_cycle_szus => idea.new_lesson ? 'New' : nil, :distribution_life_cycle_ends_szus => idea.new_lesson && idea.new_expires_at
      new_idea.tags = Tag.where(:old_id.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_idea.save
      ["image2", "image3", "zoom_image"].each do |meth|
        unless idea.send(meth).blank?
          image = new_idea.images.build
          begin
            image.remote_image_url = "http://www.sizzix.com/images/#{idea.send(meth)}"
            p image.save
          rescue Exception => e
            p e.message
          end        
        end
      end
      p new_idea.save
      p new_idea.errors
      next unless new_idea.valid?
      new_idea.reload
      new_idea.tags = Tag.where(:old_id.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_idea.save
      p new_idea.errors
      p "------ #{idea.id} #{new_idea.id}-------"
    end
    p Sunspot.commit
  end
  
  desc "migrate SZ idea tabs"
  task :idea_tabs_sz => :load_dep do
    Idea.all.each do |idea|
    #idea=Idea.find '4cf98c3fe1b8320d4c000007'
      old_idea = OldData::Idea.find(idea.old_id) rescue next
      old_idea.idea_tabs.not_deleted.each do |tab|
        next if idea.tabs.where(:name => tab.name).count > 0
        new_tab = idea.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ELLISON_SYSTEMS, :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{idea.idea_num} ------ #{tab.id} -------"
      end
    end
    p Sunspot.commit
  end
  
  desc "migrate EDU tags"
  task :tags_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::PolymorphicTag.not_deleted.find_each(:conditions => ["tag_type NOT IN (?)", [1,16]]) do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      systems = ["eeus", "er"]
      systems << "eeuk" unless ["calendar", "calendar_event", "theme", "curriculum", "subcurriculum", "subtheme"].include?(tag.old_type_to_new)
      new_tag = Tag.where(:name => tag.name, :tag_type => tag.old_type_to_new).first || Tag.new(:name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => systems, :description => tag.short_desc, :start_date_eeus => tag.start_date,  :end_date_eeus => tag.end_date, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image)
      new_tag.write_attributes :old_id_edu => tag.id, :all_day => tag.all_day, :calendar_start_date_eeus => tag.calendar_start_date, :calendar_end_date_eeus => tag.calendar_end_date, :calendar_start_date_er => tag.calendar_start_date, :calendar_end_date_er => tag.calendar_end_date, :keywords => tag.keywords, :color => tag.color
      new_tag.systems_enabled = new_tag.systems_enabled | systems unless new_tag.new_record?
      print new_tag.save
      p tag.id
    end
  end
  
  desc "fix EDU calendar tags"
  task :tags_fix_calendar => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::PolymorphicTag.not_deleted.find_each(:conditions => "calendar_start_date IS NOT NULL") do |tag|
      new_tag = Tag.where(:old_id_edu => tag.id).first 
      next unless new_tag
      new_tag.write_attributes :calendar_start_date_eeus => tag.calendar_start_date, :calendar_end_date_eeus => tag.calendar_end_date - 8.hours, :calendar_start_date_er => tag.calendar_start_date, :calendar_end_date_er => tag.calendar_end_date - 8.hours, :color => tag.color
      print new_tag.save(:validate => false)
      p tag.id
    end
  end
  
  desc "migrate EEUS products"
  task :products_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::Product.not_deleted.find_each do |product|
      #product = OldData::Product.find 8059
      new_product = Product.new :name => product.name, :description_eeus => product.short_desc, :old_id_edu => product.id, :systems_enabled => ["eeus"], :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :active => product.new_active_status, 
        :life_cycle => product.new_life_cycle, :orderable_eeus => product.new_orderable, :msrp_usd => product.msrp, :keywords => product.keywords, :start_date_eeus => product.start_date, :end_date_eeus => product.end_date, :item_code => product.item_code, :default_config => product.default_config, :handling_price_usd => product.handling_price,
        :quantity_us => product.quantity, :distribution_life_cycle_eeus => product.clearance_discontinued ? "Clearance" : product.life_cycle, :distribution_life_cycle_ends_eeus => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_eeus => product.availability_msg
      new_product.build_product_config(:name => product.product_config.name, :description => product.product_config.description, :additional_name => product.product_config.additional_name, :additional_description => product.product_config.additional_description, :config_group => product.product_config.config_group, :display_order => product.product_config.display_order, :icon => product.product_config.icon) if product.product_config

      new_product.tags = Tag.where(:old_id_edu.in => product.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_product.save
      ["image2", "image3", "embelish_image", "line_drawing", "zoom_image"].each do |meth|
        unless product.send(meth).blank?
          image = new_product.images.build
          begin
            image.remote_image_url = "http://www.ellisoneducation.com/images/#{product.send(meth)}"
            p image.save
          rescue Exception => e
            p e.message
          end        
        end
      end
      p new_product.save
      p new_product.errors
      next unless new_product.valid?
      new_product.reload
      new_product.tags = Tag.where(:old_id_edu.in => product.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_product.save
      p new_product.errors
      p "------ #{product.id} -------"
    end
    p Sunspot.commit
  end
  
  desc "migrate EDU US product tabs"
  task :tabs_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Product.where(:old_id_edu.gt => 0).each do |product|
      #product = Product.find '4cf847fbe1b8326863000227'
      old_product = OldData::Product.find(product.old_id_edu) rescue next
      old_product.tabs.not_deleted.each do |tab|
        next if product.tabs.where(:name => tab.name).count > 0
        new_tab = product.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled =>  ["eeus", "eeuk", "er"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
    p Sunspot.commit
  end
  
  desc "EDU sizes to tags"
  task :size_to_tag => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Product.where(:product_config.exists => true, 'product_config.config_group' => 'size').each do |product|
      tag = Tag.where(:tag_type => "size", :name => product.size).first || Tag.new(:tag_type => 'size', :name => product.size, :start_date_eeus => 1.year.ago, :end_date_eeus => 20.years.since, :systems_enabled => ["eeus", "eeuk", "er"])
      tag.product_ids << product.id
      product_ids = tag.product_ids.dup
      tag.products = Product.where(:_id.in => product_ids).uniq.map {|p| p}
      p tag.save
      tag.reload
      tag.product_ids = []
      tag.products = Product.where(:_id.in => product_ids).uniq.map {|p| p}
      tag.save
      p tag.product_ids
      p "#{product.item_num} ------ #{tag.name} -------"
    end
    p Sunspot.commit
  end
  
  desc "fix size_to_tab"
  task :fix_size_to_tag => [:set_edu, :load_dep] do
    Tag.sizes.each do |tag|
      product_ids = tag.product_ids.dup
      tag.products = Product.where(:_id.in => product_ids).uniq.map {|p| p}
      tag.save
      tag.reload
      tag.product_ids = []
      tag.products = Product.where(:_id.in => product_ids).uniq.map {|p| p}
      p tag.save
    end
  end
  
  desc "migrate sizzix ideas"
  task :ideas_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    #idea = OldData::Idea.find 1820
    OldData::Idea.find_each(:conditions => "id > 0") do |idea|
      new_idea = Idea.new :name => idea.name, :description_eeus => idea.short_desc, :old_id_edu => idea.id, :systems_enabled => ["eeus", "eeuk", "er"], :idea_num => "#{idea.idea_num}", :long_desc => idea.long_desc, :active => idea.active_status, 
         :keywords => idea.keywords, :start_date_eeus => idea.start_date, :end_date_eeus => idea.end_date, :objective => idea.objective, :grade_level => idea.grade_level && idea.grade_level.split(/,\s*/),
         :distribution_life_cycle_eeus => idea.new_lesson ? 'New' : nil, :distribution_life_cycle_ends_eeus => idea.new_lesson && idea.new_expires_at
      new_idea.tags = Tag.where(:old_id_edu.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_idea.save
      ["image2", "image3"].each do |meth|
        unless idea.send(meth).blank?
          image = new_idea.images.build
          begin
            image.remote_image_url = "http://www.ellisoneducation.com/images/#{idea.send(meth)}"
            p image.save
          rescue Exception => e
            p e.message
          end        
        end
      end
      p new_idea.save
      p new_idea.errors
      next unless new_idea.valid?
      new_idea.reload
      new_idea.tags = Tag.where(:old_id_edu.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      new_idea.save
      p new_idea.errors
      p "------ #{idea.id} #{new_idea.id}-------"
    end
    p Sunspot.commit
  end
  
  desc "update related idea nums with L prefix for EDU -- no need to run if idea nums will be uniq accross all sites"
  task :related_ideas_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Product.where(:old_id_edu.gt => 0, :'tabs.ideas'.exists => true).each do |product|
      # product=Product.find '4cfd6a0ee1b83207130011f2'
      product.tabs.select {|e| !e.ideas.blank?}.each do |tab|
        tab.ideas = tab.ideas.map {|e| e =~ /^L/ ? e : "L#{e}"}
        p tab.save
      end
    end
    p Sunspot.commit
  end
  
  desc "rename EDU idea images"
  task :rename_images_edu => [:set_edu, :load_dep] do
    p path =  "#{Rails.root}/public/images/"
    OldData::Idea.find_each(:conditions => "id > 0") do |idea|
      #idea = OldData::Idea.find 731
      FileUtils.mv "#{path}#{idea.large_image.gsub('ellison_lessons/', 'ellison_ideas/')}", "#{path}ellison_ideas/large/#{idea.idea_num}.jpg" if !idea.large_image.blank? && FileTest.exists?("#{path}#{idea.large_image.gsub('ellison_lessons/', 'ellison_ideas/')}") rescue next
      FileUtils.mv "#{path}#{idea.med_image.gsub('ellison_lessons/', 'ellison_ideas/')}", "#{path}ellison_ideas/medium/#{idea.idea_num}.jpg" if !idea.med_image.blank? && FileTest.exists?("#{path}#{idea.med_image.gsub('ellison_lessons/', 'ellison_ideas/')}") rescue next
      FileUtils.mv "#{path}#{idea.small_image.gsub('ellison_lessons/', 'ellison_ideas/')}", "#{path}ellison_ideas/small/#{idea.idea_num}.jpg" if !idea.small_image.blank? && FileTest.exists?("#{path}#{idea.small_image.gsub('ellison_lessons/', 'ellison_ideas/')}") rescue next
      p idea.idea_num
    end
  end
  
  desc "rename EDU product images"
  task :rename_prod_images_edu => [:set_edu, :load_dep] do
    p path =  "#{Rails.root}/public/images/"
    # product = OldData::Product.find 4351
    OldData::Product.find_each(:conditions => "small_image  NOT REGEXP 'ellison_products/small/[0-9]{5,7}(_|-)?[a-z0-9]*\.(gif|jpg)$'") do |product|
      FileUtils.cp "#{path}#{product.image}", "#{path}ellison_products/large/#{product.item_num}#{product.image[/\.(\w{3,4})$/]}" if !product.image.blank? && FileTest.exists?("#{path}#{product.image}") rescue next
      FileUtils.cp "#{path}#{product.medium_image}", "#{path}ellison_products/medium/#{product.item_num}#{product.medium_image[/\.(\w{3,4})$/]}" if !product.medium_image.blank? && FileTest.exists?("#{path}#{product.medium_image}") rescue next
      FileUtils.cp "#{path}#{product.small_image}", "#{path}ellison_products/small/#{product.item_num}#{product.small_image[/\.(\w{3,4})$/]}" if !product.small_image.blank? && FileTest.exists?("#{path}#{product.small_image}") rescue next
      p product.item_num
    end
  end
  
  desc "migrate EDU idea tabs"
  task :idea_tabs_ee => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Idea.all.each do |idea|
    #idea=Idea.find '4cfed56de1b83259d6000017'
      old_idea = OldData::Idea.find(idea.old_id_edu) rescue next
      old_idea.idea_tabs.not_deleted.each do |tab|
        next if idea.tabs.where(:name => tab.name).count > 0
        new_tab = idea.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["eeus", "eeuk", "er"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab,"edu")
        p new_tab.save
        p new_tab.errors
        p "#{idea.idea_num} ------ #{tab.id} -------"
      end
    end
    p Sunspot.commit
  end
  
  desc "import sizzix US users"
  task :users_szus => :load_dep do
    set_current_system "szus"
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      #old_user = OldData::User.find(463910)
      new_user = User.new(:email => old_user.email, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
      new_user.old_id_szus = old_user.id
      
      process_user(old_user,new_user)
      p new_user.errors
      p new_user.old_id_szus
    end
  end
  
  desc "migrate SZUS orders"
  task :orders_szus => :load_dep do
    set_current_system "szus"
    #order = OldData::Order.find(511574)
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      new_order = Order.new(:status => order.status_name, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :order_number => order.id, :order_reference => order.order_reference_id.blank? ? nil : Order.where(:order_number => order.order_reference_id).first.try(:id), :tracking_number => order.tracking_number, :tracking_url => order.tracking_url, :customer_rep => order.sales_rep.try(:email), :clickid => order.clickid, :utm_source => order.utm_source, :tracking => order.tracking,
                    :tax_transaction => order.tax_transaction_id, :tax_calculated_at => order.tax_calculated_at, :tax_exempt_number => order.tax_exempt_number, :tax_committed => order.tax_committed, :shipping_priority => order.shipping_priority, :shipping_service => "STANDARD", :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :ip_address => order.ip_address, :estimated_ship_date => order.estimated_ship_date, :purchase_order => order.purchase_order, :comments => order.comments, :internal_comments => order.internal_comments, :old_quote_id => order.quote_id)
    
      new_order.user = User.where(:old_id_szus => order.user_id).first unless order.user_id.blank?
    
      new_order.address = Address.new(:address_type => "shipping", :email => order.ship_email, :bypass_avs => true, :first_name => order.ship_first_name, :last_name => order.ship_last_name, :address1 => order.ship_address1, :address2 => order.ship_address2, :city => order.ship_city, :state => order.ship_state, :zip_code => order.ship_zip, :country => order.ship_country, :phone => order.ship_phone, :company => order.shipping_company)
    
      new_order.payment = Payment.new(:created_at => order.payment.created_at, :first_name => order.payment.first_name, :last_name => order.payment.last_name, :company => order.payment.company, :address1 => order.payment.address1, :address2 => order.payment.address2, :city => order.payment.city, :state => order.payment.state, :zip_code => order.payment.zip, :country => order.payment.country, :phone => order.payment.phone, :email => order.payment.email, :payment_method => order.payment.payment_type, :card_name => order.payment.card_name, :card_number => order.payment.card_number, :card_expiration_month => order.payment.card_expiration_month, :card_expiration_year => order.payment.card_expiration_year, :save_credit_card => order.payment.save_credit_card, :use_saved_credit_card => order.payment.use_saved_credit_card, :deferred => order.payment.deferred, :purchase_order => !order.payment.purchase_order.blank?, :purchase_order_number => order.payment.purchase_order, :cv2_result => order.payment.cv2_result, :status => order.payment.status, :vpstx_id => order.payment.vpstx_id, :security_key => order.payment.security_key, :tx_auth_no => order.payment.tx_auth_no, :status_detail => order.payment.status_detail, :address_result => order.payment.address_result, :post_code_result => order.payment.post_code_result, :subscriptionid => order.payment.subscriptionid, :paid_amount => order.payment.paid_amount, :authorization => order.payment.authorization, :paid_at => order.payment.paid_at, :vendor_tx_code => order.payment.vendor_tx_code, :void_at => order.payment.void_at, :void_amount => order.payment.void_amount, :void_authorization => order.payment.void_authorization, :refunded_at => order.payment.refunded_at, :refunded_amount => order.payment.refunded_amount, :refund_authorization => order.payment.refund_authorization, :deferred_payment_amount => order.payment.deferred_payment_amount, :number_of_payments => order.payment.number_of_payments, :frequency => order.payment.frequency) unless order.payment.blank?
    
      order.order_items.each do |item|
        new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.order.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
          :product_id => Product.where(:old_id => item.product_id).first.try(:id))
      end
     
      p new_order.save
      p new_order.errors
      p order.id
      p ' '
    end
  end
  
  desc "migrate SZUK products"
  task :products_szuk => [:set_szuk, :load_dep]  do
    set_current_system "szuk"
    # product = OldData::Product.find 758
    OldData::Product.not_deleted.find_each do |product|
      new_product = Product.where(:item_num => product.item_num).first || Product.new(:systems_enabled => ["szuk"], :name => product.name, :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :keywords => product.keywords, :life_cycle => product.new_life_cycle, :active => product.new_active_status)
      new_product.systems_enabled << "szuk" if product.new_active_status && !new_product.systems_enabled.include?("szuk")
      new_product.write_attributes :description_szuk => product.short_desc, :old_id_szuk => product.id,  :orderable_szuk => product.new_orderable, :msrp_gbp => product.msrp("UK"), :msrp_eur => product.msrp("EU"), :start_date_szuk => product.start_date, :end_date_szuk => product.end_date, :quantity_uk => product.quantity,  :distribution_life_cycle_szuk => product.life_cycle, :distribution_life_cycle_ends_szuk => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_szuk => product.availability_msg
      if !new_product.active && product.new_active_status
        p "...product needs to be activated -- removing szus"
        new_product.systems_enabled.delete("szus") 
      end
      new_product.active = true if product.new_active_status
      if product.new_life_cycle != 'unavailable' && new_product.life_cycle == 'unavailable' && product.new_active_status
        p "...product is available -- changing life cycle to discontinued"
        new_product.life_cycle = 'discontinued' 
      end
      p new_product.save
      p new_product.errors
      p "------ #{product.id} #{product.item_num} -------"
    end
    p Sunspot.commit
  end
  
  desc "fix SZUS product unavailable items -- not needed for live migration"
  task :fix_products_szus => :load_dep do
    OldData::Product.find_each(:conditions => "availability = 2 and active = 1") do |old_product|
      product = Product.where(:old_id => old_product.id).first
      next if product.blank?
      product.life_cycle = 'discontinued'
      product.systems_enabled << "szus" if !product.systems_enabled.include?("szus")
      p product.save
      p "----- #{product.item_num} -----"
    end
  end
  
  desc "import sizzix UK users"
  task :users_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    # old_user = OldData::User.find(12369)
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email).first
      if !existing.blank? && old_user.orders.count > 0
        new_user = existing
        p "user #{old_user.email} found. merging..."
        new_user.old_id_szuk = old_user.id
        new_user.systems_enabled << "szuk" if !new_user.systems_enabled.include?("szuk") 
        p new_user.save
      else
        new_user = User.new(:email => old_user.email, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_szuk = old_user.id

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      p "-------- #{new_user.old_id_szuk} #{new_user.email}----------"
    end
  end
  
  desc "migrate SZUK orders"
  task :orders_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    # order = OldData::Order.find(16025)
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      new_order = Order.new(:status => order.status_name, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.uk_tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :order_number => order.id, :order_reference => order.order_reference_id.blank? ? nil : Order.where(:order_number => order.order_reference_id).first.try(:id), :tracking_number => order.tracking_number, :tracking_url => order.tracking_url, :customer_rep => order.sales_rep.try(:email), :clickid => order.clickid, :utm_source => order.utm_source, :tracking => order.tracking,
                    :tax_transaction => order.tax_transaction_id, :tax_calculated_at => order.tax_calculated_at, :tax_exempt_number => order.tax_exempt_number, :tax_committed => order.tax_committed, :shipping_priority => order.shipping_priority, :shipping_service => "STANDARD", :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :ip_address => order.ip_address, :estimated_ship_date => order.estimated_ship_date, :purchase_order => order.purchase_order, :comments => order.comments, :internal_comments => order.internal_comments, :old_quote_id => order.quote_id)
    
      new_order.user = User.where(:old_id_szuk => order.user_id).first unless order.user_id.blank?
    
      new_order.address = Address.new(:address_type => "shipping", :email => order.ship_email, :bypass_avs => true, :first_name => order.ship_first_name, :last_name => order.ship_last_name, :address1 => order.ship_address1, :address2 => order.ship_address2, :city => order.ship_city, :state => order.ship_state, :zip_code => order.ship_zip, :country => order.ship_country, :phone => order.ship_phone, :company => order.shipping_company)
    
      new_order.payment = Payment.new(:created_at => order.payment.created_at, :first_name => order.payment.first_name, :last_name => order.payment.last_name, :company => order.payment.company, :address1 => order.payment.address1, :address2 => order.payment.address2, :city => order.payment.city, :state => order.payment.state, :zip_code => order.payment.zip, :country => order.payment.country, :phone => order.payment.phone, :email => order.payment.email, :payment_method => order.payment.payment_type, :card_name => order.payment.card_name, :card_number => order.payment.card_number, :card_expiration_month => order.payment.card_expiration_month, :card_expiration_year => order.payment.card_expiration_year, :save_credit_card => order.payment.save_credit_card, :use_saved_credit_card => order.payment.use_saved_credit_card, :deferred => order.payment.deferred, :purchase_order => !order.payment.purchase_order.blank?, :purchase_order_number => order.payment.purchase_order, :cv2_result => order.payment.cv2_result, :status => order.payment.status, :vpstx_id => order.payment.vpstx_id, :security_key => order.payment.security_key, :tx_auth_no => order.payment.tx_auth_no, :status_detail => order.payment.status_detail, :address_result => order.payment.address_result, :post_code_result => order.payment.post_code_result, :subscriptionid => order.payment.subscriptionid, :paid_amount => order.payment.paid_amount, :authorization => order.payment.authorization, :paid_at => order.payment.paid_at, :vendor_tx_code => order.payment.vendor_tx_code, :void_at => order.payment.void_at, :void_amount => order.payment.void_amount, :void_authorization => order.payment.void_authorization, :refunded_at => order.payment.refunded_at, :refunded_amount => order.payment.refunded_amount, :refund_authorization => order.payment.refund_authorization, :deferred_payment_amount => order.payment.deferred_payment_amount, :number_of_payments => order.payment.number_of_payments, :frequency => order.payment.frequency) unless order.payment.blank?
    
      order.order_items.each do |item|
        new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.order.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
          :product_id => Product.where(:old_id_szuk => item.product_id).first.try(:id))
      end
     
      p new_order.save
      p new_order.errors
      p "------- #{order.id} --------"
    end
  end
  
  def process_user(old_user,new_user)
    new_user.old_password_hash = old_user.crypted_password
    new_user.old_salt = old_user.salt
    new_user.password = new_user.old_password_hash[0..19]
    new_user.old_user = true  
    new_user.tax_exempt = old_user.tax_exempt
    new_user.tax_exempt_certificate = old_user.tax_exempt_certificate || 'N/A'
    new_user.invoice_account = old_user.billing_addresses.first.try :invoice_account
    new_user.erp = old_user.erp_id
    new_user.status = old_user.state
    new_user.old_account_id = old_user.account_id
    new_user.purchase_order = old_user.purchase_order
    new_user.discount_level = old_user.discount_level_id
    new_user.first_order_minimum = old_user.first_order_minimum
    new_user.order_minimum = old_user.order_minimum
    new_user.customer_newsletter = old_user.customer_newsletter
    new_user.outlet_newsletter = old_user.outlet_newsletter
    new_user.real_deal = old_user.real_deal
    new_user.default_user = old_user.default_user
    new_user.internal_comments = old_user.internal_comments

    p new_user.save
    unless old_user.billing_addresses.first.blank?
      p "billing address..."
      old_billing = old_user.billing_addresses.first
      billing_address = new_user.addresses.build(:address_type => "billing", :email => new_user.email, :bypass_avs => true, :first_name => old_billing.first_name, :last_name => old_billing.last_name, :address1 => old_billing.address, :address2 => old_billing.address2, :city => old_billing.city, :state => old_billing.state, :zip_code => old_billing.zip_code, :country => old_billing.country, :phone => old_billing.phone, :company => old_billing.company)
      p billing_address.save
      p billing_address.errors
      unless old_billing.subscriptionid.blank?
        p "token found..."
        new_user.token = Token.new(:subscriptionid => old_billing.subscriptionid)
        unless old_billing.tokenized_info.blank?
          new_user.token.write_attributes :first_name => old_billing.tokenized_info['firstName'], :last_name => old_billing.tokenized_info['lastName'], :address1 => old_billing.tokenized_info['street1'], :address2 => old_billing.tokenized_info['street2'], :city => old_billing.tokenized_info['city'], :state => old_billing.tokenized_info['state'], :zip_code => old_billing.tokenized_info['postalCode'], :country => old_billing.tokenized_info['country'] == 'US' ? "United States" : old_billing.tokenized_info['country'], :email => old_billing.tokenized_info['email']
        end
        p new_user.token.save
      end
    end
    unless old_user.customers.first.blank?
      p "shipping address..."
      old_shipping = old_user.customers.first
      shipping_address = new_user.addresses.build(:address_type => "shipping", :email => new_user.email, :bypass_avs => true, :first_name => old_shipping.first_name, :last_name => old_shipping.last_name, :address1 => old_shipping.address, :address2 => old_shipping.address2, :city => old_shipping.city, :state => old_shipping.state, :zip_code => old_shipping.zip_code, :country => old_shipping.country, :phone => old_shipping.phone, :company => old_shipping.company)
      p shipping_address.save
    end
  end
  
  desc "migrate SZUS wishlists"
  task :lists_szus => :load_dep do
    # old_list = OldData::Wishlist.find(649)
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_szus => old_list.user_id).first
      next unless user
      list = user.lists.build(:name => old_list.name, :default_list => old_list.default, :old_permalink => old_list.permalink, :comments => old_list.comments)
      list.product_ids = Product.where(:item_num.in => old_list.products.map {|e| e.item_num}).map {|e| e.id}
      p list.save
      p "----- #{list.user.email} -----"
    end
  end
  
  desc "migrate SZUK wishlists"
  task :lists_szuk => [:set_szuk, :load_dep] do
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_szuk => old_list.user_id).first
      next unless user
      list = user.lists.build(:name => old_list.name, :default_list => old_list.default, :old_permalink => old_list.permalink, :comments => old_list.comments)
      list.product_ids = Product.where(:item_num.in => old_list.products.map {|e| e.item_num}).map {|e| e.id}
      p list.save
      p "----- #{list.user.email} -----"
    end
  end
  
  desc "idea to product association - WARNING: overwrites existing relationship (if exists)"
  task :idea_to_products => :load_dep do
    # idea = Idea.find '4cfed69be1b83259d6000033'
    Idea.where(:product_ids.size => 0).in_batches(10) do |batch|
      batch.each do |idea|
        tab = idea.tabs.where({:name => /(products|dies) used/i}).first
        next if tab.blank?
        products = Product.where(:item_num.in => tab.products)
        idea.product_ids = []
        idea.products = products.uniq.map {|p| p}
        idea.save(:validate => false)
        idea.reload
        idea.my_product_ids = Product.where(:item_num.in => tab.products).uniq.map {|p| "#{p.id}"}.uniq
        p idea.save(:validate => false)
        p idea.errors
        idea.reload
        idea.products.each {|e| e.ideas = (e.ideas + [idea]).uniq; e.idea_ids = (e.idea_ids << idea.id).uniq; p e.save(:validate => false)}
        p "-------- #{idea.idea_num} --------"
      end
    end
  end
  
  desc "migrate ER products"
  task :products_er => [:set_er, :load_dep]  do
    set_current_system "er"
    # product = OldData::Product.find 2648 #2641
    OldData::Product.not_deleted.find_each(:conditions => "id > 0") do |product|
      new_product = Product.where(:item_num => product.item_num).first || Product.new(:systems_enabled => ["er"], :name => product.name, :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :keywords => product.keywords, :life_cycle => product.new_life_cycle, :active => product.new_active_status, :quantity_us => product.quantity)
      new_product.msrp_usd ||= product.msrp
      new_product.systems_enabled << "er" if product.new_active_status && !new_product.systems_enabled.include?("er")
      new_product.write_attributes :wholesale_price_usd => product.wholesale_price, :minimum_quantity => product.minimum_quantity, :description_er => product.short_desc, :old_id_er => product.id,  :orderable_er => product.new_orderable, :start_date_er => product.start_date, :end_date_er => product.end_date,  :distribution_life_cycle_er => product.life_cycle, :distribution_life_cycle_ends_er => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_er => product.availability_msg
      discount_category = DiscountCategory.where(:old_id => product.discount_category_id).first
      next if discount_category.blank?
      new_product.discount_category = discount_category
      if new_product.new_record?
        new_product.tags = Tag.where(:name.in => product.polymorphic_tags.map {|e| e.name}).uniq.map {|p| p}
        new_product.save
        new_product.reload
        new_product.tags = Tag.where(:name.in => product.polymorphic_tags.map {|e| e.name}).uniq.map {|p| p}
        p new_product.save
      end
      if product.release_date_string
        tag = Tag.release_dates.where(:name => product.release_date_string).first || Tag.create(:name => product.release_date_string, :tag_type => 'release_date', :systems_enabled => ["er"], :start_date_er => 2.year.ago, :end_date_er => product.release_date.end_of_day)
        product_ids = tag.product_ids.map {|e| "#{e}"}
        tag.my_product_ids = (product_ids + [new_product.id.to_s]).uniq.compact.reject {|e| e.blank?}
        tag.save
        tag_ids = new_product.tag_ids.map {|e| "#{e}"}
        new_product.my_tag_ids = (tag_ids + [tag.id.to_s]).uniq
      end
      p new_product.save
      p new_product.errors
      p "------ #{product.id} #{product.item_num} -------"
    end
    p Sunspot.commit
  end
  
  desc "process SZUK only product tabs"
  task :tabs_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    Product.where(:systems_enabled => ["szuk"], :active => true, :tabs => nil).each do |product|
      old_product = OldData::Product.find(product.old_id_szuk) rescue next
      old_product.tabs.not_deleted.each do |tab|
        next if product.tabs.where(:name => tab.name).count > 0
        new_tab = product.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["szuk"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
    p Sunspot.commit
  end
  
  desc "import ER users - IMPORTANT: copy production 'attachment' folder to the new app's root folder"
  task :users_er => [:set_er, :load_dep] do
    set_current_system "er"
    # old_user = OldData::User.find 1282
    OldData::User.not_deleted.find_each(:conditions => "id > 1323") do |old_user|
      existing = User.where(:email => old_user.email).first
      if !existing.blank? 
        new_user = existing
        p "!!! user #{old_user.email} found. merging..."
        new_user.old_id_er = old_user.id
        new_user.save
        new_user.systems_enabled << "er" if !new_user.systems_enabled.include?("er") 
        unless new_user.orders.count > 0
          new_user.systems_enabled = ["er"]
          new_user.addresses = []
          process_user(old_user,new_user)
          new_user.tax_exempt = false
        end
        p new_user.save
      else
        new_user = User.new(:email => old_user.email, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_er = old_user.id

        process_user(old_user,new_user)
      end
      if !new_user.retailer_application && old_user.retailer_info
        retailer_application = new_user.build_retailer_application(:signing_up_for => old_user.retailer_info.signing_up_for, :website => old_user.retailer_info.website, :no_website => old_user.retailer_info.no_website, :years_in_business => old_user.retailer_info.years_in_business, 
                          :number_of_employees => old_user.retailer_info.number_of_employees, :annual_sales => old_user.retailer_info.annual_sales, :resale_number => old_user.retailer_info.resale_number, :authorized_buyers => old_user.retailer_info.authorized_buyers, 
                          :business_type => old_user.retailer_info.business_type, :store_department => old_user.retailer_info.store_department, :store_location => old_user.retailer_info.store_location, :store_square_footage => old_user.retailer_info.store_square_footage, 
                          :payment_method => old_user.retailer_info.payment_method, :tax_identifier => old_user.retailer_info.tax_id, :how_did_you_learn_about_us => old_user.retailer_info.learned_from, :will_fax_documents => old_user.retailer_info.fax_later)
        RetailerApplication::AVAILABLE_BRANDS.each do |brand|
          retailer_application.brands_to_resell << brand if old_user.retailer_info.send("resell_#{brand.downcase}")
        end
        unless old_user.retailer_info.fax_later
          retailer_application.business_license = File.open(old_user.retailer_info.business_license.public_filename) if old_user.retailer_info.business_license && File.exist?(old_user.retailer_info.business_license.public_filename) && !File.extname(old_user.retailer_info.business_license.public_filename).blank?
          retailer_application.resale_tax_certificate = File.open(old_user.retailer_info.resale_tax_certificate.public_filename) if old_user.retailer_info.resale_tax_certificate && File.exist?(old_user.retailer_info.resale_tax_certificate.public_filename) && !File.extname(old_user.retailer_info.resale_tax_certificate.public_filename).blank?
          retailer_application.store_photo = File.open(old_user.retailer_info.store_photo.public_filename) if old_user.retailer_info.store_photo && File.exist?(old_user.retailer_info.store_photo.public_filename) && !File.extname(old_user.retailer_info.store_photo.public_filename).blank?
          retailer_application.save
          retailer_application.will_fax_documents = true unless retailer_application.business_license? && retailer_application.resale_tax_certificate? && retailer_application.store_photo?
        end
        p retailer_application.valid?
        p retailer_application.errors
        owner = old_user.retailer_info.owner_president.dup
        owner_first_name = owner[/\w+/]
        owner_last_name = owner.gsub(owner_first_name,'').strip
        owner_last_name = old_user.retailer_info.last_name if owner_last_name.blank?
        home_address = new_user.addresses.build(:address_type => 'home', :bypass_avs => true, :first_name => owner_first_name, :last_name => owner_last_name, :state => old_user.retailer_info.home_state, :country => old_user.retailer_info.home_country, :city => old_user.retailer_info.home_city, :address1 => old_user.retailer_info.home_address, :zip_code => old_user.retailer_info.home_zip, :email => old_user.retailer_info.email, :phone => old_user.retailer_info.phone, :company => old_user.name)
        p home_address.valid?
        p home_address.errors
        new_user.save
      end
      p new_user.errors
      p "-------- #{new_user.old_id_er} #{new_user.email}----------"
    end
  end
  
  desc "check for duplicate user accounts across systems"
  task :duplicate_users_er => [:set_er, :load_dep] do
    print "Orders in ER \t|\t email \t\t|\t active \t|\t Ord. elsewhere \t|\t Orders systems \n"
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email).first
      if existing
        print "#{old_user.orders.count} \t\t|\t #{existing.email} \t|\t #{existing.status} \t|\t #{existing.orders.count} \t|\t #{existing.orders.map {|e| e.system}}\n"
      end
    end
  end
  
  desc "migrate ER orders"
  task :orders_er => [:set_er, :load_dep] do
    set_current_system "er"
    #order = OldData::Order.find(511574)
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      new_order = Order.new(:status => order.status_name, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :order_number => order.id, :order_reference => order.order_reference_id.blank? ? nil : Order.where(:order_number => order.order_reference_id).first.try(:id), :tracking_number => order.tracking_number, :tracking_url => order.tracking_url, :customer_rep => order.sales_rep.try(:email), :clickid => order.clickid, :utm_source => order.utm_source, :tracking => order.tracking,
                    :tax_transaction => order.tax_transaction_id, :tax_calculated_at => order.tax_calculated_at, :tax_exempt_number => order.tax_exempt_number, :tax_committed => order.tax_committed, :shipping_priority => order.shipping_priority, :shipping_service => "STANDARD", :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :ip_address => order.ip_address, :estimated_ship_date => order.estimated_ship_date, :purchase_order => order.purchase_order, :comments => order.comments, :internal_comments => order.internal_comments, :old_quote_id => order.quote_id)
    
      new_order.user = User.where(:old_id_er => order.user_id).first unless order.user_id.blank?
    
      new_order.address = Address.new(:address_type => "shipping", :email => order.ship_email, :bypass_avs => true, :first_name => order.ship_first_name, :last_name => order.ship_last_name, :address1 => order.ship_address1, :address2 => order.ship_address2, :city => order.ship_city, :state => order.ship_state, :zip_code => order.ship_zip, :country => order.ship_country, :phone => order.ship_phone, :company => order.shipping_company)
    
      new_order.payment = Payment.new(:created_at => order.payment.created_at, :first_name => order.payment.first_name, :last_name => order.payment.last_name, :company => order.payment.company, :address1 => order.payment.address1, :address2 => order.payment.address2, :city => order.payment.city, :state => order.payment.state, :zip_code => order.payment.zip, :country => order.payment.country, :phone => order.payment.phone, :email => order.payment.email, :payment_method => order.payment.payment_type, :card_name => order.payment.card_name, :card_number => order.payment.card_number, :card_expiration_month => order.payment.card_expiration_month, :card_expiration_year => order.payment.card_expiration_year, :save_credit_card => order.payment.save_credit_card, :use_saved_credit_card => order.payment.use_saved_credit_card, :deferred => order.payment.deferred, :purchase_order => !order.payment.purchase_order.blank?, :purchase_order_number => order.payment.purchase_order, :cv2_result => order.payment.cv2_result, :status => order.payment.status, :vpstx_id => order.payment.vpstx_id, :security_key => order.payment.security_key, :tx_auth_no => order.payment.tx_auth_no, :status_detail => order.payment.status_detail, :address_result => order.payment.address_result, :post_code_result => order.payment.post_code_result, :subscriptionid => order.payment.subscriptionid, :paid_amount => order.payment.paid_amount, :authorization => order.payment.authorization, :paid_at => order.payment.paid_at, :vendor_tx_code => order.payment.vendor_tx_code, :void_at => order.payment.void_at, :void_amount => order.payment.void_amount, :void_authorization => order.payment.void_authorization, :refunded_at => order.payment.refunded_at, :refunded_amount => order.payment.refunded_amount, :refund_authorization => order.payment.refund_authorization, :deferred_payment_amount => order.payment.deferred_payment_amount, :number_of_payments => order.payment.number_of_payments, :frequency => order.payment.frequency) unless order.payment.blank?
    
      order.order_items.each do |item|
        new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.order.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
          :product_id => Product.where(:old_id_er => item.product_id).first.try(:id))
      end
     
      p new_order.save
      p new_order.errors
      p "-------- #{order.id} ----------"
    end
  end
  
  desc "migrate ER wishlists"
  task :lists_er => [:set_er, :load_dep] do
    set_current_system "er"
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_er => old_list.user_id).first
      next unless user
      list = user.lists.build(:name => old_list.name, :default_list => old_list.default, :old_permalink => old_list.permalink, :comments => old_list.comments)
      list.product_ids = Product.where(:item_num.in => old_list.products.map {|e| e.item_num}).map {|e| e.id}
      p list.save
      p "----- #{list.user.email} - #{user.email}-----"
    end
  end
  
  desc "migrate EDU US accounts"
  task :accounts_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::Account.not_deleted.find_each(:conditions => "id > 0") do |old_account|
      p Account.create(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :created_at => old_account.created_at, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, :old_id => old_account.id, :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
    end
  end
  
  desc "import EDU US users"
  task :users_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    # old_user = OldData::User.find(12369)
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email).first
      if !existing.blank? && old_user.orders.count > 0
        new_user = existing
        p "!!! user #{old_user.email} found. merging..."
        new_user.old_id_eeus = old_user.id
        new_user.systems_enabled << "eeus" if !new_user.systems_enabled.include?("eeus") 
        p new_user.save
      else
        new_user = User.new(:email => old_user.email, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_eeus = old_user.id

        process_user(old_user,new_user)
      end
      account = Account.where(:old_id => old_user.account_id).first
      if account
        p "account found..."
        new_user.account = account 
        new_user.save
      end
      p new_user.errors
      p "-------- #{new_user.old_id_eeus} #{new_user.email}----------"
    end
  end
  
  desc "migrate EDU US orders"
  task :orders_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    #order = OldData::Order.find(511574)
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      new_order = Order.new(:status => order.status_name, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :order_number => order.id, :order_reference => order.order_reference_id.blank? ? nil : Order.where(:order_number => order.order_reference_id).first.try(:id), :tracking_number => order.tracking_number, :tracking_url => order.tracking_url, :customer_rep => order.sales_rep.try(:email), :clickid => order.clickid, :utm_source => order.utm_source, :tracking => order.tracking,
                    :tax_transaction => order.tax_transaction_id, :tax_calculated_at => order.tax_calculated_at, :tax_exempt_number => order.tax_exempt_number, :tax_committed => order.tax_committed, :shipping_priority => order.shipping_priority, :shipping_service => "STANDARD", :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :ip_address => order.ip_address, :estimated_ship_date => order.estimated_ship_date, :purchase_order => order.purchase_order, :comments => order.comments, :internal_comments => order.internal_comments, :old_quote_id => order.quote_id)
    
      new_order.user = User.where(:old_id_eeus => order.user_id).first unless order.user_id.blank?
    
      new_order.address = Address.new(:address_type => "shipping", :email => order.ship_email, :bypass_avs => true, :first_name => order.ship_first_name, :last_name => order.ship_last_name, :address1 => order.ship_address1, :address2 => order.ship_address2, :city => order.ship_city, :state => order.ship_state, :zip_code => order.ship_zip, :country => order.ship_country, :phone => order.ship_phone, :company => order.shipping_company)
    
      new_order.payment = Payment.new(:created_at => order.payment.created_at, :first_name => order.payment.first_name, :last_name => order.payment.last_name, :company => order.payment.company, :address1 => order.payment.address1, :address2 => order.payment.address2, :city => order.payment.city, :state => order.payment.state, :zip_code => order.payment.zip, :country => order.payment.country, :phone => order.payment.phone, :email => order.payment.email, :payment_method => order.payment.payment_type, :card_name => order.payment.card_name, :card_number => order.payment.card_number, :card_expiration_month => order.payment.card_expiration_month, :card_expiration_year => order.payment.card_expiration_year, :save_credit_card => order.payment.save_credit_card, :use_saved_credit_card => order.payment.use_saved_credit_card, :deferred => order.payment.deferred, :purchase_order => !order.payment.purchase_order.blank?, :purchase_order_number => order.payment.purchase_order, :cv2_result => order.payment.cv2_result, :status => order.payment.status, :vpstx_id => order.payment.vpstx_id, :security_key => order.payment.security_key, :tx_auth_no => order.payment.tx_auth_no, :status_detail => order.payment.status_detail, :address_result => order.payment.address_result, :post_code_result => order.payment.post_code_result, :subscriptionid => order.payment.subscriptionid, :paid_amount => order.payment.paid_amount, :authorization => order.payment.authorization, :paid_at => order.payment.paid_at, :vendor_tx_code => order.payment.vendor_tx_code, :void_at => order.payment.void_at, :void_amount => order.payment.void_amount, :void_authorization => order.payment.void_authorization, :refunded_at => order.payment.refunded_at, :refunded_amount => order.payment.refunded_amount, :refund_authorization => order.payment.refund_authorization, :deferred_payment_amount => order.payment.deferred_payment_amount, :number_of_payments => order.payment.number_of_payments, :frequency => order.payment.frequency) unless order.payment.blank?
    
      order.order_items.each do |item|
        new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.order.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
          :product_id => Product.where(:old_id_eeus => item.product_id).first.try(:id))
      end
     
      p new_order.save
      p new_order.errors
      p "-------- #{order.id} ----------"
    end
  end
  
  desc "migrate EDU US wishlists"
  task :lists_eeus => [:set_edu, :load_dep] do
    set_current_system "er"
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_eeus => old_list.user_id).first
      next unless user
      list = user.lists.build(:name => old_list.name, :default_list => old_list.default, :old_permalink => old_list.permalink, :comments => old_list.comments)
      list.product_ids = Product.where(:item_num.in => old_list.products.map {|e| e.item_num}).map {|e| e.id}
      p list.save
      p "----- #{list.user.email} - #{user.email}-----"
    end
  end
  
  desc "migrate ER quotes"
  task :quotes_er => [:set_er, :load_dep] do
    set_current_system "er"
    # order = OldData::Quote.find(48)
    OldData::Quote.find_each(:conditions => "id > 0") do |order|
      new_order = Quote.new(:old_id_er => order.id, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :quote_number => order.quote, :customer_rep => order.sales_rep.try(:email), 
                    :expires_at => order.expires_at, :active => order.active, :tax_exempt_number => order.tax_exempt_number, :shipping_priority => order.shipping_priority, :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :comments => order.comments)
    
      new_order.user = User.where(:old_id_er => order.user_id).first unless order.user_id.blank?
    
      new_order.address = Address.new(:address_type => "shipping", :email => order.shipping_email, :bypass_avs => true, :first_name => order.shipping_first_name, :last_name => order.shipping_last_name, :address1 => order.shipping_address, :address2 => order.shipping_address2, :city => order.shipping_city, :state => order.shipping_state, :zip_code => order.shipping_zip, :country => order.shipping_country, :phone => order.shipping_phone, :company => order.shipping_company)
        
      order.order_items.each do |item|
        new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.quote.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
          :product_id => Product.where(:old_id_er => item.product_id).first.try(:id))
      end
     
      p new_order.save
      p new_order.errors
      p "-------- #{order.id} ----------"
    end
  end
  
  desc "migrate EDU US quotes"
  task :quotes_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    # order = OldData::Quote.find(48)
    OldData::Quote.find_each(:conditions => "id > 0") do |order|
      new_order = Quote.new(:old_id_eeus => order.id, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :quote_number => order.quote, :customer_rep => order.sales_rep.try(:email), 
                    :expires_at => order.expires_at, :active => order.active, :tax_exempt_number => order.tax_exempt_number, :shipping_priority => order.shipping_priority, :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :comments => order.comments)
    
      new_order.user = User.where(:old_id_eeus => order.user_id).first unless order.user_id.blank?
    
      new_order.address = Address.new(:address_type => "shipping", :email => order.shipping_email, :bypass_avs => true, :first_name => order.shipping_first_name, :last_name => order.shipping_last_name, :address1 => order.shipping_address, :address2 => order.shipping_address2, :city => order.shipping_city, :state => order.shipping_state, :zip_code => order.shipping_zip, :country => order.shipping_country, :phone => order.shipping_phone, :company => order.shipping_company)
        
      order.order_items.each do |item|
        new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.quote.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
          :product_id => Product.where(:old_id_edu => item.product_id).first.try(:id))
      end
     
      p new_order.save
      p new_order.errors
      p "-------- #{order.id} ----------"
    end
  end
  
  desc "calendar events only for EEUS"
  task :calendar_events_eeus_only => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Tag.calendar_events.each {|e| p e.update_attributes :systems_enabled => ["eeus", "er"]}
  end
  
  desc "import grade levels from lib/tasks/migrations/gradelevel_tags_grouped.csv"
  task :import_grade_levels  => [:set_edu, :load_dep] do
    set_current_system "eeus"
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/gradelevel_tags_grouped.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      idea = Idea.eeus.where(:idea_num => row['idea_num']).first
      #idea = Idea.eeus.where(:old_id_edu => row['id'].to_i).first
      next unless idea
      tags = Tag.grade_levels.where(:name.in => row['grade'].split(","))
      if tags.count > 0
        idea.tags.concat tags
        p idea.save(:validate => false)
        p "-------- idea #{idea.idea_num} has been saved ----------------- "
      end
    end
  end
  
  desc "import instructions from product_instructions.csv"
  task :instructions => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_instructions.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.find_by_item_num row['item_num']
      next unless @product
      p @product.update_attribute :instructions, row['pdf']
    end
  end
  
  desc "import product_item_types from product_item_types.csv"
  task :product_item_types => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_item_types.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      p @product.update_attribute :item_type, row['item_type']
    end
  end
  
  desc "import product_item_groups from product_item_groups.csv"
  task :product_item_groups => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_item_groups.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      p @product.update_attribute :item_group, row['item_group']
    end
  end
  
  desc "remove unnecessary tabs"
  task :remove_unnecessary_tabs => :load_dep do
    p 'removing Product Compatibility tabs...'
    Product.collection.update({'tabs.name' => 'Compatibility'}, {:$pull => {:tabs => {:name => 'Compatibility'}}}, :multi => true)
    p 'removing Idea Dies Used tabs...'
    Idea.collection.update({'tabs.name' => 'Dies Used'}, {:$pull => {:tabs => {:name => 'Dies Used'}}}, :multi => true)
    p 'removing Product Related Products tabs...'
    Product.collection.update({'tabs.name' => 'Related Products'}, {:$pull => {:tabs => {:name => 'Related Products'}}}, :multi => true)
    p 'removing Product Related Ideas tabs...'
    Product.collection.update({'tabs.name' => 'Related Ideas'}, {:$pull => {:tabs => {:name => 'Related Ideas'}}}, :multi => true)
    p 'renaming Idea Products Used to Other Supplies...'
    Idea.collection.update({'tabs.name' => 'Products Used'}, {:$set => {'tabs.$.name' => 'Other Supplies'}}, :multi => true)
    p "removing Idea products from Other Supplies tabs..."
    Idea.collection.update({'tabs.name' => 'Other Supplies'}, {:$set => {'tabs.$.products' => nil}}, :multi => true)
    p "deleting Idea empty Other Supplies tabs"
    Idea.where('tabs.name' => 'Other Supplies', :'tabs.text' => '').select {|e| e.tabs.detect {|t| t.name == 'Other Supplies' && t.text.blank?}}.each {|i| i.tabs.detect {|t| t.name == 'Other Supplies' && t.text.blank?}.delete}
    p 'removing Idea Related Ideas tabs...'
    Idea.collection.update({'tabs.name' => 'Related Ideas'}, {:$pull => {:tabs => {:name => 'Related Ideas'}}}, :multi => true)
  end
  
  task :set_edu do
    ENV['SYSTEM'] = "edu"
  end
  
  task :set_szuk do
    ENV['SYSTEM'] = "szuk"
  end
  
  task :set_er do
    ENV['SYSTEM'] = "er"
  end
    
  desc "load dependencies and connect to mysql db"
  task :load_dep => :environment do
    $: << File.expand_path(File.dirname(__FILE__) + '/data_migrations/vendor/attachment_fu/')
    $: << File.expand_path(File.dirname(__FILE__) + '/data_migrations/vendor/attachment_fu/lib/')
    $: << File.expand_path(File.dirname(__FILE__) + '/data_migrations/vendor/attachment_fu/lib/technoweenie/')
    $: << File.expand_path(File.dirname(__FILE__) + '/data_migrations/vendor/attachment_fu/lib/technoweenie/attachment_fu/backends/')
    $: << File.expand_path(File.dirname(__FILE__) + '/data_migrations/vendor/attachment_fu/lib/technoweenie/attachment_fu/processors/')
    
    db = case ENV['SYSTEM']
    when "edu"
      "ellison_education_qa"
    when "szuk"
      "sizzix_2_uk_qa"
    when "er"
      "ellison_global_qa"
    else
      "sizzix_2_us_qa"
    end
            
    ActiveRecord::Base.establish_connection(
        :adapter  => "mysql",
        :host     => "192.168.1.126",
        :username => "ruby",
        :password => "ellison123",
        :database => db,
        :encoding => "utf8"
      )

    class ActiveRecord::Base
      include EllisonSystem
      class << self
        include EllisonSystem
      end
    end

    Dir.glob("lib/tasks/data_migrations/*.rb").sort.each do |f|
      load f
    end
  end
end