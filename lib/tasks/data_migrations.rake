# encoding: utf-8
namespace :data_migrations do
  require "active_record/railtie"  
  require 'mongoid/railtie'
  
  desc "migrate tags"
  task :tags => :load_dep do
    OldData::PolymorphicTag.not_deleted.all(:conditions => ["tag_type NOT IN (?)", [1,16]]).each do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      new_tag = Tag.new :old_id => tag.id, :name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => ["szus", "szuk", "erus"], :description => tag.short_desc, :start_date_szus => tag.start_date, :all_day => tag.all_day, :color => tag.color,
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
        :quantity_us => product.quantity, :distribution_life_cycle_szus => product.life_cycle, :distribution_life_cycle_ends_szus => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_szus => product.availability_msg, :handling_price_usd => product.handling_price
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
      p "------ #{product.id} -------"
    end
    p Time.zone.now
  end
  
  desc "migrate SZUS product tabs"
  task :tabs_szus => :load_dep do
    Product.all.each do |product|
      #product = Product.find '4cf847fbe1b8326863000227'
      old_product = OldData::Product.find(product.old_id) rescue next
      old_product.tabs.not_deleted.each do |tab|
        next if product.tabs.where(:name => tab.name).count > 0
        new_tab = product.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["szus", "szuk", "erus"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
    p Time.zone.now
  end
  
  desc "tab test"
  task :tabs_szus_test => :load_dep do
    product = Product.find '4dc49d6be1b8325f0500094a' 
    old_product = OldData::Product.find(product.old_id)
    old_product.tabs.not_deleted.each do |tab|
      p tab.description.encoding.name
    end
  end
    
  def process_tab(tab,new_tab,sys="sz", uk =false)
    tab.name.force_encoding("UTF-8") if tab.name.encoding.name == "ASCII-8BIT"
    tab.description.force_encoding("UTF-8") if tab.description.encoding.name == "ASCII-8BIT"
    unless tab.column_grid.blank?
      new_tab.data_column ||= []
      for i in 1..OldData::Tab::MAX_GRID do
        new_tab.data_column << [tab.column_grid["left_#{i}"][0], tab.column_grid["left_#{i}"][1]] unless tab.column_grid["left_#{i}"].blank?
      end
      for i in 1..OldData::Tab::MAX_GRID do
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
          p image.remote_image_url = "http://www.#{sys == 'edu' ? "ellisoneducation" : "sizzix"}.#{uk ? 'co.uk' : 'com'}/images/#{img}"
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
      new_idea = Idea.new :name => idea.name, :description_szus => idea.short_desc, :old_id => idea.id, :systems_enabled => ["szus", "erus"], :idea_num => idea.idea_num.to_s, :long_desc => idea.long_desc, :active => idea.active_status, 
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
      p "------ #{idea.id} #{new_idea.id}-------"
    end
    p Time.zone.now
  end
  
  desc "migrate SZ idea tabs"
  task :idea_tabs_sz => :load_dep do
    Idea.all.each do |idea|
    #idea=Idea.find '4cf98c3fe1b8320d4c000007'
      old_idea = OldData::Idea.find(idea.old_id) rescue next
      old_idea.idea_tabs.not_deleted.each do |tab|
        next if idea.tabs.where(:name => tab.name).count > 0
        new_tab = idea.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["szus", "szuk", "erus"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{idea.idea_num} ------ #{tab.id} -------"
      end
    end
    p Time.zone.now
  end
  
  desc "migrate EDU tags"
  task :tags_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::PolymorphicTag.not_deleted.find_each(:conditions => ["tag_type NOT IN (?)", [1,16]]) do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      systems = ["eeus", "erus"]
      systems << "eeuk" unless ["calendar", "calendar_event", "theme", "curriculum", "subcurriculum", "subtheme"].include?(tag.old_type_to_new)
      new_tag = Tag.where(:name => tag.name, :tag_type => tag.old_type_to_new).first || Tag.new(:name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => systems, :description => tag.short_desc, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image)
      new_tag.write_attributes :old_id_edu => tag.id, :all_day => tag.all_day, :calendar_start_date_eeus => tag.calendar_start_date, :calendar_end_date_eeus => tag.calendar_end_date, :calendar_start_date_erus => tag.calendar_start_date, :start_date_eeus => tag.start_date,  :end_date_eeus => tag.end_date, :calendar_end_date_erus => tag.calendar_end_date, :keywords => tag.keywords, :color => tag.color
      new_tag.systems_enabled = new_tag.systems_enabled | systems unless new_tag.new_record?
      print new_tag.save
      p tag.id
      p new_tag.errors
    end
    p Time.zone.now
  end
  
  
  desc "migrate EDU UK theme, curriculum, subcurriculum, subtheme tags"
  task :tags_eeuk => [:set_eeuk, :load_dep] do
    set_current_system "eeuk"
    OldData::PolymorphicTag.not_deleted.find_each(:conditions => ["tag_type IN (?)", [5, 11, 17, 18]]) do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      systems = ["eeuk"]
      new_tag = Tag.where(:name => tag.name, :tag_type => tag.old_type_to_new).first || Tag.new(:name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => systems, :description => tag.short_desc, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image)
      new_tag.write_attributes :old_id_eeuk => tag.id,  :start_date_eeuk => tag.start_date,  :end_date_eeuk => tag.end_date, :keywords => tag.keywords
      new_tag.systems_enabled = new_tag.systems_enabled | systems unless new_tag.new_record?
      print new_tag.save
      p tag.id
      p new_tag.errors
    end
    p Time.now
  end
  
  desc "fix EDU calendar tags"
  task :tags_fix_calendar => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::PolymorphicTag.not_deleted.find_each(:conditions => "calendar_start_date IS NOT NULL") do |tag|
      new_tag = Tag.where(:old_id_edu => tag.id).first 
      next unless new_tag
      new_tag.write_attributes :calendar_start_date_eeus => tag.calendar_start_date, :calendar_end_date_eeus => tag.calendar_end_date - 8.hours, :calendar_start_date_erus => tag.calendar_start_date, :calendar_end_date_erus => tag.calendar_end_date - 8.hours, :color => tag.color
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
      p "------ #{product.id} -------"
    end
    p Time.zone.now
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
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled =>  ["eeus", "eeuk", "erus"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
    p Time.zone.now
  end
  
  desc "EDU sizes to tags"
  task :size_to_tag => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Product.where(:product_config.exists => true, 'product_config.config_group' => 'size').in_batches(100) do |batch|
      batch.each do |product|
        tag = Tag.where(:tag_type => "size", :name => product.size).first || Tag.create(:tag_type => 'size', :name => product.size, :start_date_eeus => 1.year.ago, :end_date_eeus => 20.years.since, :systems_enabled => ["eeus", "eeuk", "erus"])
        tag.products << product unless tag.product_ids.include? product.id
        p "#{product.item_num} ------ #{tag.name} -------"
      end
    end
    p Time.zone.now
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
  
  desc "migrate EDU ideas"
  task :ideas_edu => [:set_edu, :load_dep] do
    set_current_system "eeus"
    #idea = OldData::Idea.find 1820
    OldData::Idea.find_each(:conditions => "id > 0") do |idea|
      new_idea = Idea.create :name => idea.name, :description_eeus => idea.short_desc, :old_id_edu => idea.id, :systems_enabled => ["eeus", "erus"], :idea_num => "#{idea.idea_num}", :long_desc => idea.long_desc, :active => idea.active_status, 
         :keywords => idea.keywords, :start_date_eeus => idea.start_date, :end_date_eeus => idea.end_date, :objective => idea.objective, :grade_level => idea.grade_level && idea.grade_level.split(/,\s*/),
         :distribution_life_cycle_eeus => idea.new_lesson ? 'New' : nil, :distribution_life_cycle_ends_eeus => idea.new_lesson && idea.new_expires_at
      new_idea.tags = Tag.where(:old_id_edu.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
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
      p "------ #{idea.id} #{new_idea.id}-------"
    end
    p Time.zone.now
  end
  
  desc "migrate EDU UK ideas"
  task :ideas_eeuk => [:set_eeuk, :load_dep] do
    set_current_system "eeuk"
    #idea = OldData::Idea.find 1820
    OldData::Idea.available.find_each(:conditions => "id > 0") do |idea|
      new_idea = Idea.create :name => idea.name, :description_eeus => idea.short_desc, :old_id_eeuk => idea.id, :systems_enabled => ["eeuk"], :idea_num => "#{idea.idea_num}", :long_desc => idea.long_desc, :active => idea.active_status, 
         :keywords => idea.keywords, :start_date_eeuk => idea.start_date, :end_date_eeuk => idea.end_date, :objective => idea.objective, :grade_level => idea.grade_level && idea.grade_level.split(/,\s*/),
         :distribution_life_cycle_eeuk => idea.new_lesson ? 'New' : nil, :distribution_life_cycle_ends_eeuk => idea.new_lesson && idea.new_expires_at
      new_idea.tags = Tag.where(:old_id_eeuk.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      ["image2", "image3"].each do |meth|
        unless idea.send(meth).blank?
          image = new_idea.images.build
          begin
            image.remote_image_url = "http://www.ellisoneducation.co.uk/images/#{idea.send(meth)}"
            p image.save
          rescue Exception => e
            p e.message
          end        
        end
      end
      p new_idea.save
      p new_idea.errors
      p "------ #{idea.id} #{new_idea.id}-------"
    end
    p Time.now
  end
  
  desc "migrate EDU UK idea tabs"
  task :idea_tabs_eeuk => [:set_eeuk, :load_dep] do
    set_current_system "eeuk"
    Idea.where(:old_id_eeuk.exists => true).in_batches(100) do |batch|
      batch.each do |idea|
        #idea=Idea.find '4cfed56de1b83259d6000017'
        old_idea = OldData::Idea.find(idea.old_id_eeuk) rescue next
        old_idea.idea_tabs.not_deleted.each do |tab|
          next if idea.tabs.where(:name => tab.name).count > 0
          new_tab = idea.tabs.build 
          new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["eeuk"], :active => tab.active, :text => tab.freeform
          process_tab(tab,new_tab,"edu",true)
          p new_tab.save
          p new_tab.errors
          p "#{idea.idea_num} ------ #{tab.id} -------"
        end
      end
    end
    p Time.now
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
    p Time.zone.now
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
    # run again with (if not all tabs got migrated over):
    #Idea.active.where(:old_id_edu.gt => 0, :tabs.exists => false).in_batches(100) do |batch|
    Idea.where(:old_id_edu.exists => true).in_batches(100) do |batch|
      batch.each do |idea|
        #idea=Idea.find '4cfed56de1b83259d6000017'
        old_idea = OldData::Idea.find(idea.old_id_edu) rescue next
        old_idea.idea_tabs.not_deleted.each do |tab|
          next if idea.tabs.where(:name => tab.name).count > 0
          new_tab = idea.tabs.build 
          new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["eeus", "erus"], :active => tab.active, :text => tab.freeform
          process_tab(tab,new_tab,"edu")
          p new_tab.save
          p new_tab.errors
          p "#{idea.idea_num} ------ #{tab.id} -------"
        end
      end
    end
    p Time.zone.now
  end
  
  desc "import sizzix US users"
  task :users_szus => :load_dep do
    set_current_system "szus"
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      #old_user = OldData::User.find(463910)
      new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
      new_user.old_id_szus = old_user.id
      
      process_user(old_user,new_user)
      p new_user.errors
      p new_user.old_id_szus
    end
    p Time.zone.now
  end
  
  desc "fix szus users - NO NEED TO RUN"
  task :fix_szus_orders => [:load_dep] do
    set_current_system "szus"
    Order.where(:system => 'szus', :user_id.exists => false).each do |order|
      old_order = OldData::Order.find order.order_number
      old_user = old_order.user
      existing = User.where(:email => Regexp.new("^" + Regexp.escape(old_user.email.downcase) + "$", "i") ).first
      existing.update_attribute :old_id_szus, old_user.id if existing
      if existing.present?
        new_user = existing
        p "user #{old_user.email} found. merging..."
        new_user.update_attribute :old_id_szus, old_user.id
        new_user.systems_enabled << "szus" if !new_user.systems_enabled.include?("szus") 
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_szus = old_user.id

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      order.user = new_user if new_user.valid?
      order.save
      p "-------- #{new_user.old_id_szus} #{new_user.email}----------"
    end
  end
  
  desc "fix szuk users - NO NEED TO RUN"
  task :fix_szuk_orders => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    Order.where(:system => 'szuk', :user_id.exists => false).each do |order|
      old_order = OldData::Order.find order.order_number
      old_user = old_order.user
      existing = User.where(:email => Regexp.new("^" + Regexp.escape(old_user.email.downcase) + "$", "i") ).first
      existing.update_attribute :old_id_szuk, old_user.id if existing
      if existing.present?
        new_user = existing
        p "user #{old_user.email} found. merging..."
        new_user.update_attribute :old_id_szuk, old_user.id
        new_user.systems_enabled << "szuk" if !new_user.systems_enabled.include?("szuk") 
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_szuk = old_user.id

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      order.user = new_user if new_user.valid?
      order.save
      p "-------- #{new_user.old_id_szuk} #{new_user.email}----------"
    end
  end
  
  desc "fix erus users - NO NEED TO RUN"
  task :fix_erus_orders => [:set_er, :load_dep] do
    set_current_system "erus"
    Order.where(:system => 'erus', :user_id.exists => false).each do |order|
      old_order = OldData::Order.find order.order_number
      old_user = old_order.user
      existing = User.where(:email => Regexp.new("^" + Regexp.escape(old_user.email.downcase) + "$", "i") ).first
      existing.update_attribute :old_id_er, old_user.id if existing
      if existing.present?
        new_user = existing
        p "user #{old_user.email} found. merging..."
        new_user.update_attribute :old_id_er, old_user.id
        new_user.systems_enabled << "erus" if !new_user.systems_enabled.include?("erus") 
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_er = old_user.id

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      order.user = new_user #if new_user.valid?
      order.save
      p "-------- #{new_user.old_id_er} #{new_user.email}----------"
    end
  end
  
  desc "fix eeus users - NO NEED TO RUN"
  task :fix_eeus_orders => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Order.where(:system => 'eeus', :user_id.exists => false).each do |order|
      old_order = OldData::Order.find order.order_number
      old_user = old_order.user
      existing = User.where(:email => Regexp.new("^" + Regexp.escape(old_user.email.downcase) + "$", "i") ).first
      existing.update_attribute :old_id_eeus, old_user.id if existing
      if existing.present?
        new_user = existing
        p "user #{old_user.email} found. merging..."
        new_user.update_attribute :old_id_eeus, old_user.id
        new_user.systems_enabled << "eeus" if !new_user.systems_enabled.include?("eeus") 
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_eeus = old_user.id

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      order.user = new_user #if new_user.valid?
      order.save
      p "-------- #{new_user.old_id_eeus} #{new_user.email}----------"
    end
  end
  
  desc "migrate SZUS orders"
  task :orders_szus => :load_dep do
    set_current_system "szus"
    #order = OldData::Order.find(511574)
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      process_new_order(order, :old_id_szus, :old_id)
    end
    p Time.zone.now
  end
  
  desc "migrate SZUK products"
  task :products_szuk => [:set_szuk, :load_dep]  do
    set_current_system "szuk"
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
      if new_product.new_record?
        ["image2", "image3", "embelish_image", "line_drawing", "zoom_image"].each do |meth|
          unless product.send(meth).blank?
            image = new_product.images.build
            begin
              image.remote_image_url = "http://www.sizzix.co.uk/images/#{product.send(meth)}"
              p image.save
            rescue Exception => e
              p e.message
            end        
          end
        end
      end
      new_product.tags.concat Tag.where(:old_id_szuk.in => product.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      p new_product.save
      p new_product.errors
      p "------ #{product.id} #{product.item_num} -------"
    end
    p Time.now
  end
  
  desc "migrate EEUK products"
  task :products_eeuk => [:set_eeuk, :load_dep]  do
    set_current_system "eeuk"
    # product = OldData::Product.find 758
    OldData::Product.not_deleted.find_each do |product|
      new_product = Product.where(:item_num => product.item_num).first || Product.new(:systems_enabled => ["eeuk"], :name => product.name, :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :keywords => product.keywords, :life_cycle => product.new_life_cycle, :active => product.new_active_status)
      new_product.systems_enabled << "eeuk" if product.new_active_status && !new_product.systems_enabled.include?("eeuk")
      new_product.write_attributes :description_eeuk => product.short_desc, :old_id_eeuk => product.id,  :orderable_eeuk => product.new_orderable, :msrp_gbp => product.msrp("UK"), :msrp_eur => product.msrp("EU"), :start_date_eeuk => product.start_date, :end_date_eeuk => product.end_date, :quantity_uk => product.quantity,  :distribution_life_cycle_eeuk => product.life_cycle, :distribution_life_cycle_ends_eeuk => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_eeuk => product.availability_msg
      if !new_product.active && product.new_active_status
        p "...product needs to be activated -- removing eeus"
        new_product.systems_enabled.delete("eeus") 
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
    p Time.now
  end
  
  desc "migrate SZUK ideas"
  task :ideas_szuk => [:set_szuk, :load_dep]  do
    set_current_system "szuk"
    p OldData::Idea.available.count
    OldData::Idea.available.find_each do |idea|
      new_idea = Idea.where(:idea_num => "#{idea.idea_num}").first || Idea.new(:systems_enabled => ["szuk"], :idea_num => "#{idea.idea_num}", :name => idea.name, :description_szuk => idea.short_desc, :active => idea.active_status)

      new_idea.systems_enabled << "szuk" if !new_idea.systems_enabled.include?("szuk")

      new_idea.write_attributes :old_id_szuk => idea.id, :long_desc => idea.long_desc, :keywords => idea.keywords, :start_date_szuk => idea.start_date, :end_date_szuk => idea.end_date, :distribution_life_cycle_szuk => idea.new_lesson ? 'New' : nil, :distribution_life_cycle_ends_szuk => idea.new_lesson && idea.new_expires_at
      
      if !new_idea.active && idea.active_status
        p "...idea needs to be activated -- removing szus"
        new_idea.systems_enabled.delete("szus") 
      end
      
      if new_idea.new_record?
        ["image2", "image3", "zoom_image"].each do |meth|
          unless idea.send(meth).blank?
            image = new_idea.images.build
            begin
              image.remote_image_url = "http://www.sizzix.co.uk/images/#{idea.send(meth)}"
              p image.save
            rescue Exception => e
              p e.message
            end        
          end
        end
      end
      new_idea.active = true if idea.active_status
      p new_idea.save
      p new_idea.errors
      new_idea.tags.concat Tag.where(:old_id_szuk.in => idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      p "------ #{idea.id} #{idea.idea_num} -------"
    end
    p Time.now
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
  
  desc "migrate SZUK tags"
  task :tags_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    OldData::PolymorphicTag.not_deleted.find_each(:conditions => ["tag_type NOT IN (?)", [1,16]]) do |tag|
      tag.name.force_encoding("UTF-8") if tag.name.encoding.name == "ASCII-8BIT"
      systems = ["szuk"]
      new_tag = Tag.where(:name => tag.name, :tag_type => tag.old_type_to_new).first || Tag.new(:name => tag.name, :tag_type => tag.old_type_to_new, :active => tag.active, :systems_enabled => systems, :description => tag.short_desc, :banner => tag.banner, :list_page_image => tag.list_page_image, :medium_image => tag.medium_image)
      new_tag.write_attributes :old_id_szuk => tag.id,  :start_date_szuk => tag.start_date,  :end_date_szuk => tag.end_date, :keywords => tag.keywords
      new_tag.systems_enabled = new_tag.systems_enabled | systems unless new_tag.new_record?
      print new_tag.new_record?
      print new_tag.save
      p tag.id
      p new_tag.errors
    end
    p Time.now
  end
  
  desc "assign uk tags to uk products - NO NEED TO RUN"
  task :fix_szuk_tags => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    Product.where(:old_id_szuk.gt => 0, :systems_enabled => ["szuk"]).each do |product|
      old_product = OldData::Product.find product.old_id_szuk
      p product.tag_ids.count
      product.tags.concat Tag.where(:old_id_szuk.in => old_product.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      p "#{product.item_num} #{product.tag_ids.count} #{product.tag_ids.uniq.count}"
      p "======================"
    end
  end
  
  desc "assign uk tags to uk ideas - NO NEED TO RUN"
  task :fix_szuk_idea_tags => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    Idea.where(:old_id_szuk.gt => 0, :systems_enabled => ["szuk"]).each do |idea|
      old_idea = OldData::Idea.find idea.old_id_szuk
      p idea.tag_ids.count
      idea.tags.concat Tag.where(:old_id_szuk.in => old_idea.polymorphic_tags.map {|e| e.id}.uniq).uniq.map {|p| p}
      p "#{idea.idea_num} #{idea.tag_ids.count} #{idea.tag_ids.uniq.count}"
      p "======================"
    end
  end
  
  desc "import sizzix UK users"
  task :users_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    # old_user = OldData::User.find(12369)
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email.downcase).first
      existing.update_attribute :old_id_szuk, old_user.id if existing
      if !existing.blank? && old_user.orders.count > 0
        new_user = existing
        p "user #{old_user.email} found. merging..."
        new_user.update_attribute :old_id_szuk, old_user.id
        new_user.systems_enabled << "szuk" if !new_user.systems_enabled.include?("szuk") 
        new_user.addresses = []
        process_user(old_user,new_user)
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_szuk = old_user.id

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      p "-------- #{new_user.old_id_szuk} #{new_user.email}----------"
    end
    p Time.zone.now
  end
  
  desc "migrate SZUK orders"
  task :orders_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      process_new_order(order, :old_id_szuk, :old_id_szuk)
    end
    p Time.now
  end
  
  def process_user(old_user,new_user)
    new_user.old_password_hash = old_user.crypted_password
    new_user.old_salt = old_user.salt
    new_user.password = "A#{rand(10)}" + new_user.old_password_hash[0..12]
    new_user.old_user = true  
    new_user.tax_exempt = old_user.tax_exempt
    new_user.tax_exempt_certificate = old_user.tax_exempt_certificate || 'N/A'
    new_user.invoice_account = old_user.billing_addresses.first.try :invoice_account
    new_user.erp = old_user.erp_id if old_user.erp_id
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
    new_user.created_at = old_user.created_at
    new_user.created_by = 'migration'
    
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
  
  def process_retailer_app(new_user, old_user)
    if old_user.retailer_info
      new_user.retailer_application 
      retailer_application = new_user.retailer_application || new_user.build_retailer_application
      retailer_application.write_attributes(:signing_up_for => old_user.retailer_info.signing_up_for, :website => old_user.retailer_info.website, :no_website => old_user.retailer_info.no_website, :years_in_business => old_user.retailer_info.years_in_business, 
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
      unless new_user.home_address.present?
        home_address = new_user.addresses.build(:address_type => 'home', :job_title => old_user.retailer_info.job_title, :bypass_avs => true, :first_name => owner_first_name, :last_name => owner_last_name, :state => old_user.retailer_info.home_state, :country => old_user.retailer_info.home_country, :city => old_user.retailer_info.home_city, :address1 => old_user.retailer_info.home_address, :zip_code => old_user.retailer_info.home_zip, :email => old_user.retailer_info.email, :phone => old_user.retailer_info.phone, :company => old_user.name)
        p home_address.valid?
        p home_address.errors
      end
      new_user.save(:validate => false)
    end
  end
  
  def process_new_order(order, user_sym = :old_id_szus, product_sym = :old_id)
    new_order = Order.new(:status => order.status_name, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => is_uk? ? order.uk_tax_amount : order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :order_number => order.id, :order_reference => order.order_reference_id.blank? ? nil : Order.where(:order_number => order.order_reference_id).first.try(:id), :tracking_number => order.tracking_number, :tracking_url => order.tracking_url, :customer_rep => order.sales_rep.try(:email), :clickid => order.clickid, :utm_source => order.utm_source, :tracking => order.tracking,
                  :tax_transaction => order.tax_transaction_id, :tax_calculated_at => order.tax_calculated_at, :tax_exempt_number => order.tax_exempt_number, :tax_committed => order.tax_committed, :shipping_priority => order.shipping_priority, :shipping_service => "STANDARD", :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :ip_address => order.ip_address, :estimated_ship_date => order.estimated_ship_date, :purchase_order => order.purchase_order, :comments => order.comments, :internal_comments => order.internal_comments, :old_quote_id => order.quote_id)
  
    new_order.user = User.where(user_sym => order.user_id).first unless order.user_id.blank?
  
    new_order.address = Address.new(:address_type => "shipping", :email => order.ship_email, :bypass_avs => true, :first_name => order.ship_first_name, :last_name => order.ship_last_name, :address1 => order.ship_address1, :address2 => order.ship_address2, :city => order.ship_city, :state => order.ship_state, :zip_code => order.ship_zip, :country => order.ship_country, :phone => order.ship_phone, :company => order.shipping_company)
  
    new_order.payment = Payment.new(:created_at => order.payment.created_at, :first_name => order.payment.first_name, :last_name => order.payment.last_name, :company => order.payment.company, :address1 => order.payment.address1, :address2 => order.payment.address2, :city => order.payment.city, :state => order.payment.state, :zip_code => order.payment.zip, :country => order.payment.country, :phone => order.payment.phone, :email => order.payment.email, :payment_method => order.payment.payment_type, :card_name => order.payment.card_name, :card_number => order.payment.card_number, :card_expiration_month => order.payment.card_expiration_month, :card_expiration_year => order.payment.card_expiration_year, :save_credit_card => order.payment.save_credit_card, :use_saved_credit_card => order.payment.use_saved_credit_card, :deferred => order.payment.deferred, :purchase_order => !order.payment.purchase_order.blank?, :purchase_order_number => order.payment.purchase_order, :cv2_result => order.payment.cv2_result, :status => order.payment.status, :vpstx_id => order.payment.vpstx_id, :security_key => order.payment.security_key, :tx_auth_no => order.payment.tx_auth_no, :status_detail => order.payment.status_detail, :address_result => order.payment.address_result, :post_code_result => order.payment.post_code_result, :subscriptionid => order.payment.subscriptionid, :paid_amount => order.payment.paid_amount, :authorization => order.payment.authorization, :paid_at => order.payment.paid_at, :vendor_tx_code => order.payment.vendor_tx_code, :void_at => order.payment.void_at, :void_amount => order.payment.void_amount, :void_authorization => order.payment.void_authorization, :refunded_at => order.payment.refunded_at, :refunded_amount => order.payment.refunded_amount, :refund_authorization => order.payment.refund_authorization, :deferred_payment_amount => order.payment.deferred_payment_amount, :number_of_payments => order.payment.number_of_payments, :frequency => order.payment.frequency) unless order.payment.blank?
  
    order.order_items.each do |item|
      new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.order.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
        :product_id => Product.where(product_sym => item.product_id).first.try(:id))
    end
   
    p new_order.save
    p new_order.errors
    p "=== #{order.id} ==="
  end
  
  def process_new_quote(order, old_quote_id_sym = :old_id_eeus, user_id_sym = :old_id_eeus, product_sym = :old_id_edu)
    new_order = Quote.new(old_quote_id_sym => order.id, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :created_at => order.created_at, :total_discount => order.total_discount, :quote_number => order.quote, :customer_rep => order.sales_rep.try(:email), 
                  :expires_at => order.expires_at, :active => order.active, :tax_exempt => order.tax_exempt, :tax_exempt_number => order.tax_exempt_number, :shipping_priority => order.shipping_priority, :vat_percentage => order.order_items.first.try(:vat_percentage), :vat_exempt => order.vat_exempt, :locale => order.locale, :comments => order.comments)
  
    new_order.user = User.where(user_id_sym => order.user_id).first unless order.user_id.blank?
  
    new_order.address = Address.new(:address_type => "shipping", :email => order.shipping_email, :bypass_avs => true, :first_name => order.shipping_first_name, :last_name => order.shipping_last_name, :address1 => order.shipping_address, :address2 => order.shipping_address2, :city => order.shipping_city, :state => order.shipping_state, :zip_code => order.shipping_zip, :country => order.shipping_country, :phone => order.shipping_phone, :company => order.shipping_company)
      
    order.order_items.each do |item|
      new_order.order_items << OrderItem.new(:item_num => item.item_num, :name => item.product.try(:name), :locale => item.quote.locale, :quoted_price => item.quoted_price, :sale_price => item.sale_price, :discount => item.discount, :quantity => item.quantity, :vat_exempt => item.vat_exempt, :vat => item.vat, :vat_percentage => item.vat_percentage, :upsell => item.upsell, :outlet => item.outlet, 
        :product_id => Product.where(product_sym => item.product_id).first.try(:id))
    end
   
    p new_order.save
    p new_order.errors
    p "-------- #{order.id} ----------"
  end
    
  desc "migrate SZUS wishlists"
  task :lists_szus => :load_dep do
    # old_list = OldData::Wishlist.find(649)
    set_current_system "szus"
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_szus => old_list.user_id).first
      next unless user
      process_user_list(user,old_list)
    end
    p Time.zone.now
  end
  
  desc "migrate SZUK wishlists"
  task :lists_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_szuk => old_list.user_id).first
      next unless user
      process_user_list(user,old_list)
    end
    p Time.now
  end
  
  desc "idea to product association - WARNING: overwrites existing relationship (if exists)"
  task :idea_to_products => :load_dep do
    # idea = Idea.find '4cfed69be1b83259d6000033'
    p "Total: #{Idea.where(:'tabs.name' => /(products|dies) used/i, :product_ids.size => 0).count}"
    Idea.where(:'tabs.name' => /(products|dies) used/i, :product_ids.size => 0).in_batches(500) do |batch|
      batch.each do |idea|
        tab = idea.tabs.where({:name => /(products|dies) used/i}).first
        next if tab.blank?
        products = Product.where(:item_num.in => tab.products)
        idea.products << products.uniq.map {|p| p}
        p "-------- #{idea.idea_num} --------"
      end
    end
    p Time.zone.now
  end
  
  desc "migrate ER products"
  task :products_er => [:set_er, :load_dep]  do
    set_current_system "erus"
    # product = OldData::Product.find 2648 #2641
    OldData::Product.not_deleted.find_each(:conditions => "id > 0") do |product|
      new_product = Product.where(:item_num => product.item_num).first || Product.new(:systems_enabled => ["erus"], :name => product.name, :item_num => product.item_num, :long_desc => product.long_desc, :upc => product.upc, :keywords => product.keywords, :life_cycle => product.new_life_cycle, :active => product.new_active_status, :quantity_us => product.quantity)
      new_product.msrp_usd ||= product.msrp
      new_product.systems_enabled << "erus" if product.new_active_status && !new_product.systems_enabled.include?("erus")
      new_product.write_attributes :wholesale_price_usd => product.wholesale_price, :minimum_quantity => product.minimum_quantity, :description_erus => product.short_desc, :old_id_er => product.id,  :orderable_erus => product.new_orderable, :start_date_erus => product.start_date, :end_date_erus => product.end_date,  :distribution_life_cycle_erus => product.life_cycle, :distribution_life_cycle_ends_erus => !product.life_cycle.blank? && product.life_cycle_ends, :availability_message_erus => product.availability_msg
      discount_category = DiscountCategory.where(:old_id => product.discount_category_id).first
      next if discount_category.blank?
      new_product.discount_category = discount_category
      if new_product.new_record?
        p new_product.save
        new_product.tags << Tag.where(:name.in => product.polymorphic_tags.map {|e| e.name}).uniq.map {|p| p}
      end
      if product.release_date_string
        tag = Tag.release_dates.where(:name => product.release_date_string).first || Tag.create(:name => product.release_date_string, :tag_type => 'release_date', :systems_enabled => ["erus"], :start_date_erus => 2.year.ago, :end_date_erus => product.release_date.end_of_day)
        p " release tag #{tag.valid?}"
        new_product.tags << tag
      end
      p new_product.save
      p new_product.errors
      p "------ #{product.id} #{product.item_num} -------"
    end
    p Time.zone.now
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
    p Time.now
  end
  
  desc "process SZUK only idea tabs"
  task :idea_tabs_szuk => [:set_szuk, :load_dep] do
    set_current_system "szuk"
    Idea.where(:systems_enabled => ["szuk"], :active => true, :tabs => nil).each do |idea|
      old_idea = OldData::Idea.find(idea.old_id_szuk) rescue next
      old_idea.idea_tabs.not_deleted.each do |tab|
        next if idea.tabs.where(:name => tab.name).count > 0
        new_tab = idea.tabs.build 
        new_tab.write_attributes :name => tab.name, :description => tab.description, :systems_enabled => ["szuk"], :active => tab.active, :text => tab.freeform
        process_tab(tab,new_tab)
        p new_tab.save
        p new_tab.errors
        p "#{idea.idea_num} ------ #{tab.id} -------"
      end
    end
    p Time.now
  end
  
  desc "import ER users - IMPORTANT: copy production 'attachment' folder to the new app's root folder"
  task :users_er => [:set_er, :load_dep] do
    set_current_system "erus"
    # old_user = OldData::User.find 655
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email.downcase).first
      if !existing.blank? 
        new_user = existing
        p "!!! user #{old_user.email} found. merging..."
        new_user.update_attribute :old_id_er, old_user.id
        new_user.systems_enabled << "erus" if !new_user.systems_enabled.include?("erus") 
        if new_user.orders.count < 1
          new_user.systems_enabled = ["erus"]
          new_user.addresses = []
          process_user(old_user,new_user)
          new_user.tax_exempt = false
        else
          process_billing_address_change(old_user,new_user)
        end
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_er = old_user.id

        process_user(old_user,new_user)
      end
      process_retailer_app(new_user, old_user)
      
      p new_user.errors
      p "-------- #{new_user.old_id_er} #{new_user.email}----------"
    end
    p Time.zone.now
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
    set_current_system "erus"
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      process_new_order(order, :old_id_er, :old_id_er)
    end
    p Time.zone.now
  end
  
  desc "migrate ER wishlists"
  task :lists_er => [:set_er, :load_dep] do
    set_current_system "erus"
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_er => old_list.user_id).first
      next unless user
      process_user_list(user,old_list)
    end
    p Time.zone.now
  end
  
  desc "migrate EDU US accounts"
  task :accounts_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::Account.not_deleted.find_each(:conditions => "id > 0") do |old_account|
      a = Account.create(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :created_at => old_account.created_at, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, :old_id => old_account.id, :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
      p a.new_record?
    end
    p Time.zone.now
  end
  
  desc "import EDU US users"
  task :users_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    # old_user = OldData::User.find(12369)
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email.downcase).first
      existing.update_attribute :old_id_eeus, old_user.id if existing
      if !existing.blank? && old_user.orders.count > 0
        new_user = existing
        p "!!! user #{old_user.email} found. merging..."
        new_user.old_id_eeus = old_user.id
        new_user.systems_enabled << "eeus" if !new_user.systems_enabled.include?("eeus") 
        new_user.addresses = []
        process_user(old_user,new_user)
        new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_eeus = old_user.id

        process_user(old_user,new_user)
      end
      account = Account.where(:old_id => old_user.account_id).first
      if account
        p "account found..."
        new_user.account = account
        new_user.institution = old_user.account.institution.code.strip if old_user.account.try(:institution).try(:code)
        new_user.save
      end
      p new_user.errors
      p "-------- #{new_user.old_id_eeus} #{new_user.email}----------"
    end
    p Time.zone.now
  end
  
  desc "migrate EDU UK accounts"
  task :accounts_eeuk => [:set_eeuk, :load_dep] do
    set_current_system "eeuk"
    OldData::Account.not_deleted.find_each(:conditions => "id > 0") do |old_account|
      a = Account.create(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :created_at => old_account.created_at, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, 
          :old_id_uk => old_account.id, :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
      p a.new_record?
    end
    p Time.now
  end
  
  desc "import EDU UK users"
  task :users_eeuk => [:set_eeuk, :load_dep] do
    set_current_system "eeuk"
    # old_user = OldData::User.find(12369)
    OldData::User.not_deleted.find_each(:conditions => "id > 0") do |old_user|
      existing = User.where(:email => old_user.email.downcase).first
      existing.update_attribute :old_id_eeuk, old_user.id if existing
      if !existing.blank? && old_user.orders.count > 0
        new_user = existing
        p "!!! user #{old_user.email} found. merging..."
        new_user.old_id_eeuk = old_user.id
        new_user.systems_enabled << "eeuk" if !new_user.systems_enabled.include?("eeuk") 
        new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email.downcase, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.old_id_eeuk = old_user.id

        process_user(old_user,new_user)
      end
      account = Account.where(:old_id_uk => old_user.account_id).first
      if account
        p "account found..."
        new_user.account = account
        new_user.institution = old_user.account.institution.code.strip if old_user.account.try(:institution).try(:code)
        new_user.save
      end
      p new_user.errors
      p "-------- #{new_user.old_id_eeus} #{new_user.email}----------"
    end
    p Time.now
  end
  
  desc "migrate EDU US orders"
  task :orders_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    OldData::Order.find_each(:conditions => "id > 0") do |order|
      process_new_order(order, :old_id_eeus, :old_id_edu)
    end
    p Time.now
  end
  
  desc "migrate EDU US wishlists"
  task :lists_eeus => [:set_edu, :load_dep] do
    set_current_system "erus"
    OldData::Wishlist.active.find_each(:conditions => "id > 0") do |old_list|
      user = User.where(:old_id_eeus => old_list.user_id).first
      next unless user
      process_user_list(user,old_list)
    end
    p Time.zone.now
  end
  
  desc "migrate ER quotes"
  task :quotes_er => [:set_er, :load_dep] do
    set_current_system "erus"
    OldData::Quote.find_each(:conditions => "id > 0") do |order|
      process_new_quote(old_order, :old_id_er, :old_id_er, :old_id_er)
    end
    p Time.zone.now
  end
  
  desc "migrate EDU US quotes"
  task :quotes_eeus => [:set_edu, :load_dep] do
    set_current_system "eeus"
    # order = OldData::Quote.find(48)
    OldData::Quote.find_each(:conditions => "id > 0") do |order|
      process_new_quote(order, :old_id_eeus, :old_id_eeus, :old_id_edu)
    end
    p Time.zone.now
  end
  
  desc "calendar events only for EEUS"
  task :calendar_events_eeus_only => [:set_edu, :load_dep] do
    set_current_system "eeus"
    Tag.calendar_events.each {|e| p e.update_attributes :systems_enabled => ["eeus", "erus"]}
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
    p Time.zone.now
  end
  
  desc "import instructions from lib/tasks/migrations/product_instructions.csv"
  task :instructions => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_instructions.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.find_by_item_num row['item_num']
      next unless @product
      p @product.update_attribute :instructions, row['pdf']
    end
    p Time.zone.now
  end
  
  desc "import product_item_types from lib/tasks/migrations/product_item_types.csv"
  task :product_item_types => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_item_types.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      p @product.update_attribute :item_type, row['item_type']
    end
    p Time.zone.now
  end
  
  desc "import product_item_groups from lib/tasks/migrations/product_item_groups.csv"
  task :product_item_groups => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_item_groups.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      p @product.update_attribute :item_group, row['item_group']
    end
    p Time.zone.now
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
    
    # p 'renaming Idea Products Used to Other Supplies...'
    # Idea.collection.update({'tabs.name' => 'Products Used'}, {:$set => {'tabs.$.name' => 'Other Supplies'}}, :multi => true)
    # p "removing Idea products from Other Supplies tabs..."
    # Idea.collection.update({'tabs.name' => 'Other Supplies'}, {:$set => {'tabs.$.products' => nil}}, :multi => true)
    # p "deleting Idea empty Other Supplies tabs"
    # Idea.where('tabs.name' => 'Other Supplies', :'tabs.text' => '').select {|e| e.tabs.detect {|t| t.name == 'Other Supplies' && t.text.blank?}}.each {|i| i.tabs.detect {|t| t.name == 'Other Supplies' && t.text.blank?}.delete}
    p "removing Idea Products Used tabs..."
    Idea.collection.update({'tabs.name' => 'Products Used'}, {:$pull => {:tabs => {:name => 'Products Used'}}}, :multi => true)
    p 'removing Idea Related Ideas tabs...'
    Idea.collection.update({'tabs.name' => 'Related Ideas'}, {:$pull => {:tabs => {:name => 'Related Ideas'}}}, :multi => true)
    p 'removing Idea Equipment Choices tabs...'
    Idea.collection.update({'tabs.name' => 'Equipment Choices'}, {:$pull => {:tabs => {:name => 'Equipment Choices'}}}, :multi => true)
    p 'removing Idea Materials Used tabs...'
    Idea.collection.update({'tabs.name' => 'Materials Used'}, {:$pull => {:tabs => {:name => 'Materials Used'}}}, :multi => true)
  end
  
  desc "populate retailer discount matrix starting from 17 Prestige & RollModel Accessories. -- not needed for live migration"
  task :fix_discount_matrix => :environment do
    @matrix = CSV.open(File.expand_path(File.dirname(__FILE__) + "/migrations/discount_matrix.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"').to_a
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/discount_categories.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      next if row["id"].to_i < 17
      @discount_category = DiscountCategory.new(:name => row["name"], :old_id => row["id"])
      RetailerDiscountLevels.instance.levels.each do |level|
        @discount_category.send("discount_#{level.id}=", @matrix.detect {|e| e["discount_level_id"] == "#{level.id}" && e["discount_category_id"] == row["id"]}["discount"])
      end
      @discount_category.save!
	  end
	  p Time.zone.now
	end
	
	desc "import education_products_on_er from lib/tasks/migrations/education_products_on_er.csv"
  task :education_products_on_er => [:set_er, :load_dep] do
    set_current_system "eeus"
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/education_products_on_er.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      @product.minimum_quantity = row['min_qty_er'].to_i
      @product.discount_category_id = DiscountCategory.where(:old_id => row['discount_id']).first.try(:id)
      @product.systems_enabled << "erus" unless @product.systems_enabled.include?("erus")
      @product.send :inherit_system_specific_attributes
      p @product.save(:validate => false)
    end
    p Time.zone.now
  end
  
  desc "import product_item_weights from lib/tasks/migrations/product_item_weight.csv"
  task :product_item_weights => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/product_item_weight.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      p @product.update_attribute :weight, row['weight']
    end
    p Time.zone.now
  end
  
  desc "import USPS zones"
  task :usps_zones => :load_dep do
    OldData::UspsZone.find_each(:conditions => "id > 0") do |zone|
      p UspsZone.create :zip_prefix => zone.zip_prefix, :zone => zone.zone
    end
  end
  
  desc "import stores data from lib/tasks/migrations/global_store_locator_data.csv"
  task :store_locator => :load_dep do
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/global_store_locator_data.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      begin
        Store.create :store_number => row['store_number'], :active => row['active_status'], :name => row['store_name'], :webstore => row['web_store'], :physical_store => row['physical_store'], 
        :brands => row['brands'].split(/,\s*/), :product_line => row['product_line'].split(/,\s*/), :agent_type => row['agent_type'], :authorized_reseller_type => row['authorized_reseller_type'],
        :excellence_level => row['excellence_level'], :has_ellison_design_centers => row['has_ellison_design_centers'], :address1 => row['address'], 
        :address2 => row['address2'], :city => row['city'], :state => row['state'], :zip_code => row['zip'], :country => row['country'], :contact_person => row['contact_person'], 
        :phone => row['phone'], :fax => row['fax'], :email => row['email'], :website => row['website'], :keyword => row['keyword'], :internal_comments => row['internal_comments']
      rescue Exception => e
        p "#{row['store_number']} geocoding failed. record skipped."
      end
    end
    p Time.zone.now
  end
  
  desc "import lyris subscriptions"
  task :lyris_subscriptions => :environment do
    NEWSLETTER_SEGMENTS.each do |list|
      if File.exists?(File.expand_path(File.dirname(__FILE__) + "/migrations/#{list.last.keys.first}.csv"))
        set_current_system list.first.to_s
        get_list_and_segments
        CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/#{list.last.keys.first}.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
          @subscription = Subscription.new 
          @subscription.email = row['email']
          @subscription.confirmed = true
          @subscription.list = subscription_list
          @subscription.list_name = @list[1]
          @segments.keys.map(&:to_s).each do |segment|
            @subscription.segments << segment if row[segment] == "1"
          end
          @subscription.save
          p "===== #{@subscription.valid?} #{@subscription.email} #{@subscription.list} ===="
          Lyris.delay.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @subscription.segments.map {|e| {:name => e.to_sym, :value => 1}} << {:name => :subscription_id, :value => @subscription.id.to_s}
        end
      end
    end
  end
  
  desc "import sizzix_product_compatability data from lib/tasks/migrations/sizzix_product_compatability.csv"
  task :sizzix_product_compatability => :load_dep do
    set_current_system "szus"
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/sizzix_product_compatability.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @tag = Tag.where(:old_id => row['tag_id']).first
      if @tag
        @compatibility = @tag.compatibilities.build
        related_tag = Tag.where(:old_id => row['related_id']).first
        if related_tag
          @compatibility.tag_id = related_tag.id
          @compatibility.product_item_nums = row['product_item_nums']
          p "main tag #{row['tag_id']} #{row['product_line']} related tag #{row['related_id']} #{row['related_product_line']} saved #{@compatibility.save}"
        else
          p "related tag #{row['related_id']} #{row['related_product_line']} was not found"
        end
      else
        p "main tag #{row['tag_id']} #{row['product_line']} was not found"
      end
    end
    p Time.now
  end
  
  desc "import ellison_product_compatability data from lib/tasks/migrations/ellison_product_compatability.csv"
  task :ellison_product_compatability => :load_dep do
    set_current_system "eeus"
    CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/ellison_product_compatability.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @tag = Tag.where(:old_id_edu => row['tag_id']).first
      if @tag
        @compatibility = @tag.compatibilities.build
        related_tag = Tag.where(:old_id_edu => row['related_id']).first
        if related_tag
          @compatibility.tag_id = related_tag.id
          @compatibility.product_item_nums = row['product_item_nums']
          p "main tag #{row['tag_id']} #{row['product_line']} related tag #{row['related_id']} #{row['related_product_line']} saved #{@compatibility.save}"
        else
          p "related tag #{row['related_id']} #{row['related_product_line']} was not found"
        end
      else
        p "main tag #{row['tag_id']} #{row['product_line']} was not found"
      end
    end
    p Time.now
  end
  
  desc "populate first admin user"
  task :populate_admin_user => :environment do
    @admin = Admin.new :name => 'Root Admin', :email => 'admin@ellison.com', :password => 'gwp2012Admin', :password_confirmation => 'gwp2012Admin', :employee_number => "Admin"
    @admin.active = @admin.can_act_as_customer = @admin.can_change_prices = true
    @admin.systems_enabled = ELLISON_SYSTEMS
    Permission::ADMIN_MODULES.each do |permission|
      @admin.permissions.build :name => permission, :systems_enabled => ELLISON_SYSTEMS, :write => true
    end
    p "admin has been created: #{@admin.save}"
  end
  
  #### INCREMENTAL MIGRATIONS START HERE ####
  
  def process_user_changes(old_user,new_user)
    new_user.old_password_hash = old_user.crypted_password
    new_user.old_salt = old_user.salt
    new_user.password = "A#{rand(10)}" + new_user.old_password_hash[0..12]
    new_user.tax_exempt = old_user.tax_exempt
    new_user.tax_exempt_certificate = old_user.tax_exempt_certificate || 'N/A'
    new_user.invoice_account = old_user.billing_addresses.first.try :invoice_account
    new_user.erp = old_user.erp_id if old_user.erp_id
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
    
    new_user.save(:validate => false)
  end
  
  def process_billing_address_change(old_user,new_user)
    unless old_user.billing_addresses.first.blank?
      p "billing address..."
      old_billing = old_user.billing_addresses.first
      billing_address = new_user.billing_address || new_user.addresses.build
      billing_address.write_attributes(:address_type => "billing", :email => new_user.email, :bypass_avs => true, :first_name => old_billing.first_name, :last_name => old_billing.last_name, :address1 => old_billing.address, :address2 => old_billing.address2, :city => old_billing.city, :state => old_billing.state, :zip_code => old_billing.zip_code, :country => old_billing.country, :phone => old_billing.phone, :company => old_billing.company)
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
      p "=== #{new_user.email} ==="
    end
  end
  
  def process_shipping_address_change(old_user,new_user)
    unless old_user.customers.first.blank?
      p "shipping address..."
      old_shipping = old_user.customers.first
      shipping_address = new_user.shipping_address || new_user.addresses.build
      shipping_address.write_attributes(:address_type => "shipping", :email => new_user.email, :bypass_avs => true, :first_name => old_shipping.first_name, :last_name => old_shipping.last_name, :address1 => old_shipping.address, :address2 => old_shipping.address2, :city => old_shipping.city, :state => old_shipping.state, :zip_code => old_shipping.zip_code, :country => old_shipping.country, :phone => old_shipping.phone, :company => old_shipping.company)
      p shipping_address.save
      p shipping_address.errors
      p "=== #{new_user.email} ==="
    end
  end
  
  def process_incremental_users(sym)
    last_user = User.where(sym.gt => 0).desc(sym).first
    last_id = last_user.send(sym)
    
    p "# of new users since last migrations: #{OldData::User.count(:conditions => ["id > ?", last_id])}"
    OldData::User.find_each(:conditions => ["id > ?", last_id]) do |old_user|
      existing = User.where(:email => old_user.email.downcase).first
      if !existing.blank? 
        new_user = existing
        p "!!! user #{old_user.email} found. merging..."
        new_user.update_attribute sym, old_user.id
        new_user.systems_enabled << "erus" if is_er? && !new_user.systems_enabled.include?("erus") && sym == :old_id_er
        if is_er? && sym == :old_id_er && new_user.orders.count < 1
          new_user.systems_enabled = ["erus"]
          new_user.addresses = []
          process_user(old_user,new_user)
          new_user.tax_exempt = false
        end
        p new_user.save(:validate => false)
      else
        new_user = User.new(:email => old_user.email, :company => old_user.name, :name => "#{old_user.first_name} #{old_user.last_name}")
        new_user.send("#{sym}=", old_user.id)

        process_user(old_user,new_user)
      end
      
      p new_user.errors
      p "=== #{old_user.id} #{new_user.email} ==="
      
      process_retailer_app(new_user, old_user) if is_er? && sym == :old_id_er
    end
    
    p "# of changed users since last migrations: #{OldData::User.count(:conditions => ["updated_at > ? AND id <= ?", last_user.created_at, last_id])}"
    OldData::User.find_each(:conditions => ["updated_at > ? AND id <= ?", last_user.created_at, last_id]) do |old_user|
      new_user = User.where(sym => old_user.id).first
      next unless new_user
      process_user_changes(old_user,new_user)
      p "==== #{old_user.id} #{new_user.email} ==="
    end
    
    p "# of changed billing addresses since last migrations: #{OldData::BillingAddress.count(:conditions => ["updated_at > ? AND user_id <= ?", last_user.created_at, last_id])}"
    OldData::BillingAddress.find_each(:conditions => ["updated_at > ? AND user_id <= ?", last_user.created_at, last_id]) do |address|
      old_user = address.user
      new_user = User.where(sym => old_user.id).first
      next unless new_user
      process_billing_address_change(old_user,new_user)
    end
    
    p "# of changed shipping addresses since last migrations: #{OldData::Customer.count(:conditions => ["updated_at > ? AND user_id <= ?", last_user.created_at, last_id])}"
    OldData::Customer.find_each(:conditions => ["updated_at > ? AND user_id <= ?", last_user.created_at, last_id]) do |address|
      old_user = address.user
      new_user = User.where(sym => old_user.id).first
      next unless new_user
      process_shipping_address_change(old_user,new_user)
    end
    
    if sym == :old_id_er
      
    end
  end
  
  def process_user_list(user,old_list)
    list = user.lists.build(:name => old_list.name, :created_at => old_list.created_at, :default_list => old_list.default, :old_permalink => old_list.permalink, :comments => old_list.comments)
    list.product_ids = Product.where(:item_num.in => old_list.products.map {|e| e.item_num}).map {|e| e.id}
    p list.save
    p "----- #{user.email} -----"
  end
  
  def process_list_changes(last_list, first_new_record)
    
    first_new_record_id = first_new_record ? first_new_record.id : OldData::Wishlist.last.id + 1
    
    p "# of changed wishlists #{OldData::Wishlist.count(:conditions => ["updated_at > ? AND id < ?", last_list.created_at, first_new_record_id])}"
    OldData::Wishlist.find_each(:conditions => ["updated_at > ? AND id < ?", last_list.created_at, first_new_record_id]) do |old_list|
      list = List.where(:system => current_system, :old_permalink => old_list.permalink).first
      next unless list
      p list.update_attributes(:name => old_list.name, :default_list => old_list.default, :comments => old_list.comments, :active => !old_list.deleted)
      p "===== list id: #{old_list.id} ===="
    end
    
    p "# of changed wishlist items #{OldData::ProductsWishlist.count(:conditions => ["updated_at > ? AND wishlist_id < ?", last_list.created_at, first_new_record_id])}"
    OldData::ProductsWishlist.find_each(:conditions => ["updated_at > ? AND wishlist_id < ?", last_list.created_at, first_new_record_id]) do |products_wishlist|
      old_list = products_wishlist.wishlist
      list = List.where(:system => current_system, :old_permalink => old_list.permalink).first
      next unless list
      product = Product.where(:item_num => products_wishlist.product.try(:item_num)).first
      list.add_product(product.id) if product
      p "=== products_wishlist id: #{products_wishlist.id} item_num: #{product.try(:item_num)} ==="
    end
  end
  
  def process_order_changes(order)
    new_order = Order.where(:order_number =>order.id).first
    if new_order
      new_order.write_attributes(:status => order.status_name, :subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => is_uk? ? order.uk_tax_amount : order.tax_amount, :total_discount => order.total_discount, :tracking_number => order.tracking_number, :tracking_url => order.tracking_url, :tracking => order.tracking,
                    :tax_transaction => order.tax_transaction_id, :tax_calculated_at => order.tax_calculated_at, :tax_exempt_number => order.tax_exempt_number, :tax_committed => order.tax_committed, :estimated_ship_date => order.estimated_ship_date, :purchase_order => order.purchase_order, :internal_comments => order.internal_comments)
      
      new_order.payment = Payment.new(:created_at => order.payment.created_at, :first_name => order.payment.first_name, :last_name => order.payment.last_name, :company => order.payment.company, :address1 => order.payment.address1, :address2 => order.payment.address2, :city => order.payment.city, :state => order.payment.state, :zip_code => order.payment.zip, :country => order.payment.country, :phone => order.payment.phone, :email => order.payment.email, :payment_method => order.payment.payment_type, :card_name => order.payment.card_name, :card_number => order.payment.card_number, :card_expiration_month => order.payment.card_expiration_month, :card_expiration_year => order.payment.card_expiration_year, :save_credit_card => order.payment.save_credit_card, :use_saved_credit_card => order.payment.use_saved_credit_card, :deferred => order.payment.deferred, :purchase_order => !order.payment.purchase_order.blank?, :purchase_order_number => order.payment.purchase_order, :cv2_result => order.payment.cv2_result, :status => order.payment.status, :vpstx_id => order.payment.vpstx_id, :security_key => order.payment.security_key, :tx_auth_no => order.payment.tx_auth_no, :status_detail => order.payment.status_detail, :address_result => order.payment.address_result, :post_code_result => order.payment.post_code_result, :subscriptionid => order.payment.subscriptionid, :paid_amount => order.payment.paid_amount, :authorization => order.payment.authorization, :paid_at => order.payment.paid_at, :vendor_tx_code => order.payment.vendor_tx_code, :void_at => order.payment.void_at, :void_amount => order.payment.void_amount, :void_authorization => order.payment.void_authorization, :refunded_at => order.payment.refunded_at, :refunded_amount => order.payment.refunded_amount, :refund_authorization => order.payment.refund_authorization, :deferred_payment_amount => order.payment.deferred_payment_amount, :number_of_payments => order.payment.number_of_payments, :frequency => order.payment.frequency) unless order.payment.blank?
   
      p new_order.save
      p new_order.errors
      p "=== #{order.id} ==="
    else
      "!!!! order #{order.id} NOT FOUND"
    end
  end
  
  def process_quote_changes(order, old_quote_id_sym = :old_id_eeus)
    new_order = Quote.where(old_quote_id_sym => order.id).first
    if new_order
      new_order.write_attributes(:subtotal_amount => order.subtotal_amount, :shipping_amount => order.shipping_amount, :handling_amount => order.handling_amount, :tax_amount => order.tax_amount, :expires_at => order.expires_at, :active => order.active, :comments => order.comments)
    
      p new_order.save
      p new_order.errors
      p "-------- #{order.id} ----------"
    else
      "!!!! order #{order.id} NOT FOUND"
    end
  end
  
  desc "incremental - users SZUS"
  task :incremental_users_szus => [:load_dep]  do
    p Time.now
    set_current_system "szus"
    process_incremental_users(:old_id_szus)
    p Time.now
  end
  
  desc "incremental - users SZUK"
  task :incremental_users_szuk => [:set_szuk, :load_dep]  do
    p Time.now
    set_current_system "szuk"
    process_incremental_users(:old_id_szuk)
    p Time.now
  end
  
  desc "incremental - users EEUS"
  task :incremental_users_eeus => [:set_eeus, :load_dep]  do
    p Time.now
    set_current_system "eeus"
    
    last_account = Account.where(:old_id.gt => 0).desc(:old_id).first
    p last_id = last_account.old_id
    
    p "# of new accounts since last migrations: #{OldData::Account.count(:conditions => ["id > ?", last_id])}"
    OldData::Account.find_each(:conditions => ["id > ?", last_id]) do |old_account|
      a = Account.create(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :created_at => old_account.created_at, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, 
              :old_id => old_account.id, :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
      p a.new_record?
    end
    
    p "# of changed accounts since last migrations: #{OldData::Account.count(:conditions => ["updated_at > ? and id <= ?", last_account.created_at, last_id])}"
    OldData::Account.find_each(:conditions => ["updated_at > ? and id <= ?", last_account.created_at, last_id]) do |old_account|
      account = Account.where(:old_id => old_account.id).first
      next unless account
      account.update_attributes(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, 
               :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
      p "#{old_account.id}"
    end
    
    process_incremental_users(:old_id_eeus)
    
    p Time.now
  end
  
  desc "incremental - users ERUS"
  task :incremental_users_erus => [:set_erus, :load_dep]  do
    p Time.now
    set_current_system "erus"
    last_user = User.where(:old_id_er.gt => 0).desc(:old_id_er).first
    p last_id = last_user.send(:old_id_er) #1682

    process_incremental_users(:old_id_er)
    
    p "# of changed retailer applications since last migrations: #{OldData::RetailerInfo.count(:conditions => ["updated_at > ? AND user_id <= ?", last_user.created_at, last_id])}"
    OldData::RetailerInfo.find_each(:conditions => ["updated_at > ? AND user_id <= ?", last_user.created_at, last_id]) do |retailer_app|
      old_user = retailer_app.user
      new_user = User.where(:old_id_er => old_user.id).first
      process_retailer_app(new_user, old_user)
    end
    p Time.now
  end
  
  desc "incremental - users EEUK"
  task :incremental_users_eeuk => [:set_eeuk, :load_dep]  do
    p Time.now
    set_current_system "eeuk"
    
    last_account = Account.where(:old_id_uk.gt => 0).desc(:old_id_uk).first
    p last_id = last_account.old_id
    
    p "# of new accounts since last migrations: #{OldData::Account.count(:conditions => ["id > ?", last_id])}"
    OldData::Account.find_each(:conditions => ["id > ?", last_id]) do |old_account|
      a = Account.create(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :created_at => old_account.created_at, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, 
              :old_id_uk => old_account.id, :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
      p a.new_record?
    end
    
    p "# of changed accounts since last migrations: #{OldData::Account.count(:conditions => ["updated_at > ? and id <= ?", last_account.created_at, last_id])}"
    OldData::Account.find_each(:conditions => ["updated_at > ? and id <= ?", last_account.created_at, last_id]) do |old_account|
      account = Account.where(:old_id_uk => old_account.id).first
      next unless account
      account.update_attributes(:school => old_account.school, :name => old_account.name, :city => old_account.city, :erp => old_account.axapta_id, :address1 => old_account.address, :address2 => old_account.address1, :zip_code => old_account.zip, :title => old_account.title, :country => old_account.country,  :avocation => old_account.avocation, :students => old_account.students, :individual => old_account.individual, 
               :institution => old_account.institution.try(:name), :resale_number => old_account.resale_number, :phone => old_account.phone, :fax => old_account.fax, :description => old_account.description, :affiliation => old_account.affiliation, :tax_exempt_number => old_account.tax_exempt_number, :tax_exempt => old_account.tax_exempt, :state => old_account.state, :email => old_account.email, :active => old_account.active)
      p "#{old_account.id}"
    end
    
    process_incremental_users(:old_id_eeuk)
    p Time.now
  end
  
  desc "incremental - wishlists SZUS"
  task :incremental_lists_szus => [:load_dep]  do
    p Time.now
    
    set_current_system "szus"
    
    last_list = List.where(:system => current_system, :old_permalink.exists => true).descending(:created_at).first
    p "# of new Wishlist since last migrations: #{OldData::Wishlist.count(:conditions => ["created_at > ?", last_list.created_at])}"
    first_new_record = OldData::Wishlist.first(:conditions => ["created_at > ?", last_list.created_at], :order => "created_at ASC")
    
    p "first new record: #{first_new_record.id}" if first_new_record
    OldData::Wishlist.find_each(:conditions => ["created_at > ?", last_list.created_at]) do |old_list|
      
      user = User.where(:old_id_szus => old_list.user_id).first
      
      next unless user
      process_user_list(user,old_list)
    end
    
    process_list_changes(last_list, first_new_record)
    p Time.now
  end
  
  
  desc "incremental - orders SZUS"
  task :incremental_orders_szus => [:load_dep]  do
    set_current_system "szus"

    last_order = Order.szus.where(:order_number.lt => 1000000).desc(:created_at).first
    
    p "last_order # #{last_order.order_number}"
    
    p "# of new orders since last migrations: #{OldData::Order.count(:conditions => ["id > ?", last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["id > ?", last_order.order_number]) do |old_order|
      process_new_order(old_order, :old_id_szus, :old_id)
    end
    
    p "# of changed orders since last migrations: #{OldData::Order.count(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number]) do |old_order|
      process_order_changes(old_order)
    end
  end
  
  desc "incremental - orders SZUK"
  task :incremental_orders_szuk => [:set_szuk, :load_dep]  do
    set_current_system "szuk"

    last_order = Order.szuk.where(:order_number.lt => 1000000).desc(:created_at).first
    
    p "last_order # #{last_order.order_number}"
    
    p "# of new orders since last migrations: #{OldData::Order.count(:conditions => ["id > ?", last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["id > ?", last_order.order_number]) do |old_order|
      process_new_order(old_order, :old_id_szuk, :old_id_szuk)
    end
    
    p "# of changed orders since last migrations: #{OldData::Order.count(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number]) do |old_order|
      process_order_changes(old_order)
    end
  end
  
  desc "incremental - orders EEUS"
  task :incremental_orders_eeus => [:set_eeus, :load_dep]  do
    set_current_system "eeus"

    last_order = Order.eeus.where(:order_number.lt => 1000000).desc(:created_at).first
    
    p "last_order # #{last_order.order_number}"
    
    p "# of new orders since last migrations: #{OldData::Order.count(:conditions => ["id > ?", last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["id > ?", last_order.order_number]) do |old_order|
      process_new_order(old_order, :old_id_eeus, :old_id_edu)
    end
    
    p "# of changed orders since last migrations: #{OldData::Order.count(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number]) do |old_order|
      process_order_changes(old_order)
    end
  end
  
  desc "incremental - orders ERUS"
  task :incremental_orders_erus => [:set_erus, :load_dep]  do
    set_current_system "erus"

    last_order = Order.erus.where(:order_number.lt => 1000000).desc(:created_at).first
    
    p "last_order # #{last_order.order_number}"
    
    p "# of new orders since last migrations: #{OldData::Order.count(:conditions => ["id > ?", last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["id > ?", last_order.order_number]) do |old_order|
      process_new_order(old_order, :old_id_er, :old_id_er)
    end
    
    p "# of changed orders since last migrations: #{OldData::Order.count(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number])}"
    OldData::Order.find_each(:conditions => ["updated_at > ? and id <= ?", last_order.created_at, last_order.order_number]) do |old_order|
      process_order_changes(old_order)
    end
  end

  desc "incremental - quotes EEUS"
  task :incremental_quotes_eeus => [:set_eeus, :load_dep]  do
    set_current_system "eeus"

    last_quote = Quote.eeus.where(:old_id_eeus.gt => 0).desc(:created_at).first    
    
    p "last_quote # #{last_quote.old_id_eeus} #{last_quote.quote_number}"
    
    p "# of new quotes since last migrations: #{OldData::Quote.count(:conditions => ["id > ?", last_quote.old_id_eeus])}"
    OldData::Quote.find_each(:conditions => ["id > ?", last_quote.old_id_eeus]) do |old_order|
      process_new_quote(old_order, :old_id_eeus, :old_id_eeus, :old_id_edu)
    end
    # 
    p "# of changed quotes since last migrations: #{OldData::Quote.count(:conditions => ["updated_at > ? and id <= ?", last_quote.created_at, last_quote.old_id_eeus])}"
    OldData::Quote.find_each(:conditions => ["updated_at > ? and id <= ?", last_quote.created_at, last_quote.old_id_eeus]) do |old_order|
      process_quote_changes(old_order, :old_id_eeus)
    end
  end
  
  desc "incremental - quotes ERUS"
  task :incremental_quotes_erus => [:set_erus, :load_dep]  do
    set_current_system "erus"

    last_quote = Quote.erus.where(:old_id_er.gt => 0).desc(:created_at).first    
    
    p "last_quote # #{last_quote.old_id_er} #{last_quote.quote_number}"
    
    p "# of new quotes since last migrations: #{OldData::Quote.count(:conditions => ["id > ?", last_quote.old_id_er])}"
    OldData::Quote.find_each(:conditions => ["id > ?", last_quote.old_id_er]) do |old_order|
      process_new_quote(old_order, :old_id_er, :old_id_er, :old_id_er)
    end
    # 
    p "# of changed quotes since last migrations: #{OldData::Quote.count(:conditions => ["updated_at > ? and id <= ?", last_quote.created_at, last_quote.old_id_er])}"
    OldData::Quote.find_each(:conditions => ["updated_at > ? and id <= ?", last_quote.created_at, last_quote.old_id_er]) do |old_order|
      process_quote_changes(old_order, :old_id_er)
    end
  end

  #### INCREMENTAL MIGRATIONS END HERE ####


  
  desc "change ER to ERUS in the db"
  task :er_to_erus => :environment do
    set_current_system "erus"
    p "updating products..."
    Product.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating ideas..."
    Idea.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating admins..."
    Admin.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating users..."
    User.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating countries..."
    Country.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating coupons..."
    Coupon.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating events..."
    Event.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating Feedbacks..."
    Feedback.collection.update({:system => "er"}, {:$set => {"system" => "erus"}}, :multi => true)
    p "updating LandingPages..."
    LandingPage.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating Navigation..."
    Navigation.collection.update({:system => "er"}, {:$set => {"system" => "erus"}}, :multi => true)
    p "updating Orders..."
    Order.collection.update({:system => "er"}, {:$set => {"system" => "erus"}}, :multi => true)
    p "updating Quotes..."
    Quote.collection.update({:system => "er"}, {:$set => {"system" => "erus"}}, :multi => true)
    p "updating SearchPhrases..."
    SearchPhrase.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating SharedContents..."
    SharedContent.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    p "updating ShippingRates..."
    ShippingRate.collection.update({:system => "er"}, {:$set => {"system" => "erus"}}, :multi => true)
    p "updating StaticPage..."
    StaticPage.collection.update({:system_enabled => "er"}, {:$set => {"system" => "erus"}}, :multi => true)
    p "updating tags..."
    Tag.collection.update({:systems_enabled => "er"}, {:$set => {"systems_enabled.$" => "erus"}}, :multi => true)
    
    # embedded:
    p "updating campaigns..."
    Product.collection.update({'campaigns.systems_enabled' => 'er'}, {:$push => {'campaigns.$.systems_enabled' => 'erus'}}, :multi => true)
    Product.collection.update({'campaigns.systems_enabled' => 'er'}, {:$pull => {'campaigns.$.systems_enabled' => 'er'}}, :multi => true)
    Tag.collection.update({'campaigns.systems_enabled' => 'er'}, {:$push => {'campaigns.$.systems_enabled' => 'erus'}}, :multi => true)
    Tag.collection.update({'campaigns.systems_enabled' => 'er'}, {:$pull => {'campaigns.$.systems_enabled' => 'er'}}, :multi => true)
    p "updating permissions..."
    Admin.collection.update({'permissions.systems_enabled' => 'er'}, {:$push => {'permissions.$.systems_enabled' => 'erus'}}, :multi => true)    
    Admin.collection.update({'permissions.systems_enabled' => 'er'}, {:$pull => {'permissions.$.systems_enabled' => 'er'}}, :multi => true)    
    p "updating tabs..."
    Product.collection.update({'tabs.systems_enabled' => 'er'}, {:$push => {'tabs.$.systems_enabled' => 'erus'}}, :multi => true)
    Product.collection.update({'tabs.systems_enabled' => 'er'}, {:$pull => {'tabs.$.systems_enabled' => 'er'}}, :multi => true)
    Idea.collection.update({'tabs.systems_enabled' => 'er'}, {:$push => {'tabs.$.systems_enabled' => 'erus'}}, :multi => true)
    Idea.collection.update({'tabs.systems_enabled' => 'er'}, {:$pull => {'tabs.$.systems_enabled' => 'er'}}, :multi => true)
    p "updating visual_assets..."
    Tag.collection.update({'visual_assets.systems_enabled' => 'er'}, {:$push => {'visual_assets.$.systems_enabled' => 'erus'}}, :multi => true)
    Tag.collection.update({'visual_assets.systems_enabled' => 'er'}, {:$pull => {'visual_assets.$.systems_enabled' => 'er'}}, :multi => true)
    LandingPage.collection.update({'visual_assets.systems_enabled' => 'er'}, {:$push => {'visual_assets.$.systems_enabled' => 'erus'}}, :multi => true)
    LandingPage.collection.update({'visual_assets.systems_enabled' => 'er'}, {:$pull => {'visual_assets.$.systems_enabled' => 'er'}}, :multi => true)
    SharedContent.collection.update({'visual_assets.systems_enabled' => 'er'}, {:$push => {'visual_assets.$.systems_enabled' => 'erus'}}, :multi => true)
    SharedContent.collection.update({'visual_assets.systems_enabled' => 'er'}, {:$pull => {'visual_assets.$.systems_enabled' => 'er'}}, :multi => true)
    
  
    js = <<-EOF
    db = db.getSisterDB("#{Mongoid.database.name}")
    db.coupons.update({start_date_er:  {$exists : true }}, {$rename : {start_date_er : 'start_date_erus'}},false,true)
    db.coupons.update({end_date_er:  {$exists : true }}, {$rename : {end_date_er : 'end_date_erus'}},false,true)
    db.coupons.update({description_er:  {$exists : true }}, {$rename : {description_er : 'description_erus'}},false,true)
    db.products.update({description_er:  {$exists : true }}, {$rename : {description_er : 'description_erus'}},false,true)
    db.products.update({orderable_er:  {$exists : true }}, {$rename : {orderable_er : 'orderable_erus'}},false,true)
    db.products.update({start_date_er:  {$exists : true }}, {$rename : {start_date_er : 'start_date_erus'}},false,true)
    db.products.update({end_date_er:  {$exists : true }}, {$rename : {end_date_er : 'end_date_erus'}},false,true)
    db.products.update({distribution_life_cycle_er:  {$exists : true }}, {$rename : {distribution_life_cycle_er : 'distribution_life_cycle_erus'}},false,true)
    db.products.update({distribution_life_cycle_ends_er:  {$exists : true }}, {$rename : {distribution_life_cycle_ends_er : 'distribution_life_cycle_ends_erus'}},false,true)
    db.products.update({availability_message_er:  {$exists : true }}, {$rename : {availability_message_er : 'availability_message_erus'}},false,true)

    db.ideas.update({description_er:  {$exists : true }}, {$rename : {description_er : 'description_erus'}},false,true)
    db.ideas.update({start_date_er:  {$exists : true }}, {$rename : {start_date_er : 'start_date_erus'}},false,true)
    db.ideas.update({end_date_er:  {$exists : true }}, {$rename : {end_date_er : 'end_date_erus'}},false,true)
    db.ideas.update({distribution_life_cycle_er:  {$exists : true }}, {$rename : {distribution_life_cycle_er : 'distribution_life_cycle_erus'}},false,true)
    db.ideas.update({distribution_life_cycle_ends_er:  {$exists : true }}, {$rename : {distribution_life_cycle_ends_er : 'distribution_life_cycle_ends_erus'}},false,true)

    db.tags.update({start_date_er:  {$exists : true }}, {$rename : {start_date_er : 'start_date_erus'}},false,true)
    db.tags.update({end_date_er:  {$exists : true }}, {$rename : {end_date_er : 'end_date_erus'}},false,true)
    db.tags.update({calendar_start_date_er:  {$exists : true }}, {$rename : {calendar_start_date_er : 'calendar_start_date_erus'}},false,true)
    db.tags.update({calendar_end_date_er:  {$exists : true }}, {$rename : {calendar_end_date_er : 'calendar_end_date_erus'}},false,true)
EOF
    
    File.open("#{Rails.root}/tmp/er_to_erus.js", "w") {|file| file.write(js)}
    
    p `mongo #{Rails.root}/tmp/er_to_erus.js`
    `rm #{Rails.root}/tmp/er_to_erus.js`
  end
  
  task :set_edu do
    ENV['SYSTEM'] = "edu"
  end
  
  task :set_eeus do
    ENV['SYSTEM'] = "edu"
  end
  
  task :set_szuk do
    ENV['SYSTEM'] = "szuk"
  end
  
  task :set_er do
    ENV['SYSTEM'] = "erus"
  end
  
  task :set_erus do
    ENV['SYSTEM'] = "erus"
  end
  
  task :set_eeuk do
    ENV['SYSTEM'] = "eeuk"
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
      "ellison_education_qa1"
    when "szuk"
      "sizzix_2_uk_qa1"
    when "erus"
      "ellison_global_qa1"
    when "eeuk"
      "ellison_education_uk_qa1"
    else
      "sizzix_2_us_qa1"
    end

    ActiveRecord::Base.default_timezone = :utc
    ActiveRecord::Base.time_zone_aware_attributes = true
            
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
    
    disable_solr_indexing!
  end
end