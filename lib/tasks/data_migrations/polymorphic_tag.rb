# encoding: utf-8
module OldData
  class PolymorphicTag < ActiveRecord::Base
  	TYPES = {1 => :campaign, 2 => :category, 4 => :machine, 5 => :theme,  8 => :designer, 9 => :brand, 11 => :subtheme, 12 => :subcategory, 13 => :subbrand, 14 => :material, 15 => :artist, 16 => :exclusive_campaign}
  	TYPES.merge!({17 => :curriculum, 18 => :subcurriculum, 19 => :calendar}) if is_ee?

  	LAYOUTS = [["A (medium image with text)", 1], ["B (full size banner)", 2], ["C (half banner + short desc)", 3], ["D (4 products)", 4], ["E (4 ideas)", 5]]

  	has_and_belongs_to_many :products, :uniq => true, :validate => false
  	has_and_belongs_to_many :ideas, :uniq => true, :validate => false

  	validates_presence_of :name
  	validates_presence_of :parent_id, :if => Proc.new(&:multi_level?)
  	validates_numericality_of :tag_type
  	validates_format_of :featured_products, :with => /^\d+,\d+,\d+,\d+$/, :message => "is invalid. Use product ID's separated by ','. Valid format example: 37,6,83,1094", :if => Proc.new {|p| p.landing_page && p.layout == 4}
  	validates_format_of :featured_ideas, :with => /^\d+,\d+,\d+,\d+$/, :message => "is invalid. Use idea ID's separated by ','. Valid format example: 37,6,83,1094", :if => Proc.new {|p| p.landing_page && p.layout == 5}

  	after_save :delete_cache_key

    # has_event_calendar :start_at_field  => 'calendar_start_date', :end_at_field => 'calendar_end_date'

  	class << self
  		def get_type_id(tag_type)
  			TYPES.detect {|v| v[1] == tag_type.to_s.downcase.to_sym}.first rescue nil
  		end
  	end

  	named_scope :available, lambda {{ :conditions => ['polymorphic_tags.active = ? AND polymorphic_tags.deleted = ? AND polymorphic_tags.start_date <= ? AND polymorphic_tags.end_date >= ?', true, false, Time.zone.now, Time.zone.now] } }
  	named_scope :active, :conditions => ['active = ? AND deleted = ?', true, false]
  	named_scope :inactive, :conditions => ['active = ? AND deleted = ?', false, false]
  	named_scope :top_level, :conditions => ['polymorphic_tags.parent_id = ?', 0]
  	named_scope :sort_by_name, :order => "polymorphic_tags.name"
  	named_scope :ordered, :order => "case when polymorphic_tags.display_order IS NULL then 9999 else polymorphic_tags.display_order end, polymorphic_tags.name"
  	named_scope :landing_page, :conditions => ['polymorphic_tags.landing_page = ?', true]
  	named_scope :no_landing_page, :conditions => ['polymorphic_tags.landing_page = ?', false]
  	named_scope :not_deleted, :conditions => ['polymorphic_tags.deleted = ?', false]
  	named_scope :name_only, :select => "id, name"


    # named scopes for sub-tags. Ex: all_themes = themes + subthemes
  	%w(theme brand category campaign).each do |sub|
  	  class_eval "named_scope :all_#{sub.pluralize}, :conditions => ['polymorphic_tags.tag_type IN (?)', TYPES.select {|k,v| v.to_s.include?(\"#{sub}\") }.map {|a| a[0]}]	"	
  	end

  	TYPES.values.each do |e| 	
  		# create named_scope for each tag_type e.g: PolymorphicTag.categories #=> Scope of category polymorphic_tags
  		class_eval "named_scope :#{e.to_s.pluralize}, :conditions => ['polymorphic_tags.tag_type = ?', PolymorphicTag.get_type_id(\"#{e}\")]	"																								

  		# create #tag? #category? ... etc. instance methods for each tag_type											# def tag? 
  		class_eval "def #{e}?\n  tag_type == self.class.get_type_id(\"#{e}\") \n end"      				# 	tag_type == self.class.get_type_id "tag"												
  	end                      													                                        	# end

  	# has multi level hierarchy structure? (category or theme)?
  	def multi_level?
  		false #category?
  	end

  	def type_name
  		TYPES[tag_type]
  	end
  	
  	def old_type_to_new
  	  {16 => "exclusive", 5=>"theme", 11=>"subtheme", 12=>"subcategory", 1=> "special", 13=> "product_family", 2=>"category", 8=>"designer", 14=>"material_compatibility", 9=> "product_line", 15=>"artist", 4=>"machine_compatibility", 17 => "curriculum", 18 => "subcurriculum", 19 => "calendar_event"}[self.tag_type]
  	end

  	def type_title
  		f = type_name.to_s.gsub(/(poly_)|(_ids)|(_facet)|(_regular)/, "").titleize
  		if f == "Campaign"
  			"Special"
  		elsif f == "Material"
  			"Material Compatibility"
  		elsif f == "Machine"
  			"Machine Compatibility"
  		elsif f == "Exclusive Campaign"
  		  "Exclusive"
  		elsif f == "Brand"
  		  "Product Line"
  		elsif f == "Subbrand"
  		  "Product Family"
  		elsif f == "Subtheme"
  		  "Theme"
  		elsif f == "Subcategory"
  		  "Category"
  		elsif f == "Subcurriculum"
  		  "Curriculum"
  		elsif f == "Calendar"
  		  "Calendar Event"
  		elsif f == "Grade"
  		  "Grade Level"
  		else
  			f
  		end
  	end

  	def filter_key
  		"poly_#{type_name.to_s.pluralize}_ids".to_sym
  	end

  	def current?
  		start_date <= Time.zone.now && end_date >= Time.zone.now
  	end

  	# default banner if banner is not defined
  	def banner
  		read_attribute('banner') ? read_attribute('banner') : "/images/catalog/banners/welcome_full.jpg"
  	end

  	# default medium_image if medium_image is not defined
  	def medium_image
  		read_attribute('medium_image') ? read_attribute('medium_image') : "products/large/noimage.jpg"
  	end

  	def destroy
    	update_attribute :deleted, true
    end

  	def adjust_all_day_dates
      if self[:all_day]
        self[self.class.start_at_field.to_sym] = self[self.class.start_at_field.to_sym].beginning_of_day
        if self[self.class.end_at_field.to_sym]
          self[self.class.end_at_field.to_sym] = self[self.class.end_at_field.to_sym].beginning_of_day + 1.day - 1.second
        else
          self[self.class.end_at_field.to_sym] = self[self.class.start_at_field.to_sym].beginning_of_day + 1.day - 1.second
        end
      end
    end

  private

  	def delete_cache_key
  		Rails.cache.delete("all_#{type_name}_polymorphic_tags") if multi_level?
  		true # not to halt filter chain
  	end
  end
  
end