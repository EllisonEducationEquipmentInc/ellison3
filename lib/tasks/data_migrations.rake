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
              new_tab.compatibility << OldData::Product.all(:select => "item_num", :conditions => ["id IN (?)", comp.reject {|e| e.blank?}]).map {|e| e.item_num}
            end
          end
          new_tab.products = OldData::Product.all(:select => "item_num", :conditions => ["id IN (?)", tab.item_nums[:products].compact.uniq]).map {|e| e.item_num} unless tab.item_nums[:products].blank?
          new_tab.ideas = OldData::Idea.all(:conditions => ["id IN (?)", tab.item_nums[:ideas].compact.uniq]).map {|e| e.idea_num} unless tab.item_nums[:ideas].blank?
          unless tab.images.blank?
            i=0
            tab.images["large_images"].reject {|e| e.blank?}.each do |img|
              image = new_tab.images.build
              image.caption = tab.images["captions"][i]
              begin
                image.remote_image_url = "http://www.sizzix.com/images/#{img}"
                p image.save
              rescue Exception => e
                p e.message
              ensure
                i+=1
              end
            end
          end
        end
        p new_tab.save
        p new_tab.errors
        p "#{product.item_num} ------ #{tab.id} -------"
      end
    end
  end
  
  desc "load dependencies and connect to mysql db"
  task :load_dep => :environment do

    ActiveRecord::Base.establish_connection(
        :adapter  => "mysql",
        :host     => "192.168.1.126",
        :username => "ruby",
        :password => "ellison123",
        :database => "sizzix_2_us_qa",
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