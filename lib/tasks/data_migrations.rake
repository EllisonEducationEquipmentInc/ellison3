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
      ["image2", "image3", "embelish_image", "line_drawing"].each do |meth|
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
      ["image2", "image3"].each do |meth|
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
      ["image2", "image3", "embelish_image", "line_drawing"].each do |meth|
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
  
  task :set_edu do
    ENV['SYSTEM'] = "edu"
  end
    
  desc "load dependencies and connect to mysql db"
  task :load_dep => :environment do

    db = case ENV['SYSTEM']
    when "edu"
      "ellison_education_qa"
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