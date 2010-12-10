# encoding: utf-8
namespace :data_migrations do
  require "active_record/railtie"  
  
  desc "test"
  task :test => :load_dep  do
    p OldData::Idea.all(:conditions => ["id IN (?)", [627, 509, 560, 726]]).map {|e| e.idea_num}
  end
  
  desc "migrate tags"
  task :tags => :load_dep do
    OldData::PolymorphicTag.not_deleted.all(:conditions => ["tag_type NOT IN (?)", [1,16]]).each do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      new_tag = Tag.new :old_id => tag.id, :name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => ELLISON_SYSTEMS, :description => tag.short_desc, :start_date_szus => tag.start_date, :all_day => tag.all_day,
        :end_date_szus => tag.end_date, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image, :calendar_start_date => tag.calendar_start_date, :calendar_end_date => tag.calendar_end_date
      print new_tag.save
      p tag.id
    end
  end
  
  desc "migrate SZUS products"
  task :products_szus => :load_dep do
    OldData::Product.not_deleted.all.each do |product|
      #product = OldData::Product.find 102 #2011 #67
      new_product = Product.new :name => product.name, :description_szus => product.short_desc, :old_id => product.id, :systems_enabled => ["szus"], :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :active => product.new_active_status, 
        :outlet => product.clearance, :outlet_since => product.outlet_since, :life_cycle => product.new_life_cycle, :orderable_szus => product.new_orderable, :msrp_usd => product.msrp, :keywords => product.keywords, :start_date_szus => product.start_date, :end_date_szus => product.end_date, 
        :quantity_us => product.quantity, :availability_message_szus => product.availability_message, :distribution_life_cycle_szus => product.life_cycle, :distribution_life_cycle_ends_szus => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_szus => product.availability_msg
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
  end
  
  desc "migrate SZUS product tabs"
  task :tabs_szus => :load_dep do
    Product.all.each do |product|
      #product = Product.find '4cf847fbe1b8326863000227'
      old_product = OldData::Product.find(product.old_id) rescue next
      old_product.tabs.not_deleted.each do |tab|
        next if product.tabs.where(:name => tab.name).count > 0
        new_tab = product.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ELLISON_SYSTEMS, :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
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
          new_tab.compatibility << OldData::Product.all(:select => "item_num", :conditions => ["id IN (?)", comp.reject {|e| e.blank?}]).map {|e| e.item_num}
        end
      end
      new_tab.products = OldData::Product.all(:select => "item_num", :conditions => ["id IN (?)", tab.item_nums[:products].compact.uniq]).map {|e| e.item_num} unless tab.item_nums[:products].blank?
      new_tab.ideas = OldData::Idea.all(:conditions => ["id IN (?)", tab.item_nums[:ideas].compact.uniq]).map {|e| e.idea_num} unless tab.item_nums[:ideas].blank?
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
    OldData::Idea.all.each do |idea|
      new_idea = Idea.new :name => idea.name, :description_szus => idea.short_desc, :old_id => idea.id, :systems_enabled => ["szus", "szuk", "er"], :idea_num => idea.idea_num, :long_desc => idea.long_desc, :active => idea.active_status, 
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
  end
  
  desc "migrate EDU tags"
  task :tags_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::PolymorphicTag.not_deleted.all(:conditions => ["tag_type NOT IN (?)", [1,16]]).each do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      new_tag = Tag.where(:name => tag.name, :tag_type => tag.old_type_to_new).first || Tag.new(:name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => ["eeus", "eeuk", "er"], :description => tag.short_desc, :start_date_eeus => tag.start_date,  :end_date_eeus => tag.end_date, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image)
      new_tag.write_attributes :old_id_edu => tag.id, :all_day => tag.all_day, :calendar_start_date => tag.calendar_start_date, :calendar_end_date => tag.calendar_end_date
      print new_tag.save
      p tag.id
    end
  end
  
  desc "migrate EEUS products"
  task :products_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::Product.not_deleted.all.each do |product|
      #product = OldData::Product.find 8059
      new_product = Product.new :name => product.name, :description_eeus => product.short_desc, :old_id_edu => product.id, :systems_enabled => ["eeus"], :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :active => product.new_active_status, 
        :life_cycle => product.new_life_cycle, :orderable_eeus => product.new_orderable, :msrp_usd => product.msrp, :keywords => product.keywords, :start_date_eeus => product.start_date, :end_date_eeus => product.end_date, :item_code => product.item_code, :default_config => product.default_config,
        :quantity_us => product.quantity, :availability_message_eeus => product.availability_message, :distribution_life_cycle_eeus => product.life_cycle, :distribution_life_cycle_ends_eeus => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_eeus => product.availability_msg
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
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ELLISON_SYSTEMS, :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
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
    OldData::Idea.all(:conditions => "id > 0").each do |idea|
      new_idea = Idea.new :name => idea.name, :description_eeus => idea.short_desc, :old_id_edu => idea.id, :systems_enabled => ["eeus", "eeuk", "er"], :idea_num => "L#{idea.idea_num}", :long_desc => idea.long_desc, :active => idea.active_status, 
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
  end
  
  desc "update related idea nums EDU"
  task :related_ideas_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Product.where(:old_id_edu.gt => 0, :'tabs.ideas'.exists => true).each do |product|
      # product=Product.find '4cfd6a0ee1b83207130011f2'
      product.tabs.select {|e| !e.ideas.blank?}.each do |tab|
        tab.ideas = tab.ideas.map {|e| e =~ /^L/ ? e : "L#{e}"}
        p tab.save
      end
    end
  end
  
  desc "rename EDU idea images"
  task :rename_images_edu => [:set_edu, :load_dep] do
    p path =  "#{Rails.root}/public/images/"
    OldData::Idea.all(:conditions => "id > 0").each do |idea|
      #idea = OldData::Idea.find 731
      FileUtils.mv "#{path}#{idea.large_image.gsub('ellison_lessons/', 'ellison_ideas/')}", "#{path}ellison_ideas/large/L#{idea.idea_num}.jpg" if !idea.large_image.blank? && FileTest.exists?("#{path}#{idea.large_image.gsub('ellison_lessons/', 'ellison_ideas/')}") rescue next
      FileUtils.mv "#{path}#{idea.med_image.gsub('ellison_lessons/', 'ellison_ideas/')}", "#{path}ellison_ideas/medium/L#{idea.idea_num}.jpg" if !idea.med_image.blank? && FileTest.exists?("#{path}#{idea.med_image.gsub('ellison_lessons/', 'ellison_ideas/')}") rescue next
      FileUtils.mv "#{path}#{idea.small_image.gsub('ellison_lessons/', 'ellison_ideas/')}", "#{path}ellison_ideas/small/L#{idea.idea_num}.jpg" if !idea.small_image.blank? && FileTest.exists?("#{path}#{idea.small_image.gsub('ellison_lessons/', 'ellison_ideas/')}") rescue next
      p idea.idea_num
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
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ELLISON_SYSTEMS, :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab,"edu")
        p new_tab.save
        p new_tab.errors
        p "#{idea.idea_num} ------ #{tab.id} -------"
      end
    end
  end
  
  desc "import sizzix US users"
  task :users_szus => :load_dep do
    set_current_system "szus"
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      #old_user = OldData::User.find(463910)
      new_user = User.new(:email => old_user.email, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
      new_user.old_password_hash = old_user.crypted_password
      new_user.old_salt = old_user.salt
      new_user.password = new_user.old_password_hash[0..19]
      new_user.old_user = true
    
      new_user.old_id_szus = old_user.id
    
      new_user.tax_exempt = old_user.tax_exempt
      new_user.tax_exempt_certificate = old_user.tax_exempt_certificate
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
      p new_user.errors
      p new_user.old_id_szus
    end
  end
  
  desc "migrate SZUS orders"
  task :orders_szus => :load_dep do
    set_current_system "szus"
    #order = OldData::Order.find(511574)
    OldData::Order.find_each(:conditions => "id > 437144") do |order|
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
    OldData::Product.not_deleted.all.each do |product|
      new_product = Product.where(:item_num => product.item_num).first || Product.new(:systems_enabled => ["szuk"], :name => product.name, :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :keywords => product.keywords, :life_cycle => product.new_life_cycle, :active => product.new_active_status)
      new_product.systems_enabled << "szuk" if product.new_active_status && !new_product.systems_enabled.include?("szuk")
      new_product.write_attributes :description_szuk => product.short_desc, :old_id_szuk => product.id,  :orderable_szuk => product.new_orderable, :msrp_gbp => product.msrp("UK"), :msrp_eur => product.msrp("EU"), :start_date_szuk => product.start_date, :end_date_szuk => product.end_date, :quantity_uk => product.quantity,  :distribution_life_cycle_szuk => product.life_cycle, :distribution_life_cycle_ends_szuk => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_szuk => product.availability_msg
      if !new_product.active && product.new_active_status
        p "...product needs to be activated -- removing szus"
        new_product.systems_enabled.delete("szus") 
      end
      new_product.active = true if product.new_active_status
      if product.new_life_cycle != 'unvailable' && new_product.life_cycle == 'unvailable' && product.new_active_status
        p "...product is available -- changing life cycle to discontinued"
        new_product.life_cycle = 'discontinued' 
      end
      p new_product.save
      p new_product.errors
      p "------ #{product.id} #{product.item_num} -------"
    end
  end
  
  desc "fix SZUS product unavailable items -- not needed for live migration"
  task :fix_products_szus => :load_dep do
    OldData::Product.all(:conditions => "availability = 2 and active = 1").each do |old_product|
      product = Product.where(:old_id => old_product.id).first
      next if product.blank?
      product.life_cycle = 'discontinued'
      product.systems_enabled << "szus" if !product.systems_enabled.include?("szus")
      p product.save
      p "----- #{product.item_num} -----"
    end
  end
  
  task :set_edu do
    ENV['SYSTEM'] = "edu"
  end
  
  task :set_szuk do
    ENV['SYSTEM'] = "szuk"
  end
    
  desc "load dependencies and connect to mysql db"
  task :load_dep => :environment do

    db = case ENV['SYSTEM']
    when "edu"
      "ellison_education_qa"
    when "szuk"
      "sizzix_2_uk_qa"
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