module OldData
  class Campaign < ActiveRecord::Base

    #after_save :flush_cache

    #has_and_belongs_to_many :products, :validate => false

    named_scope :available, lambda {{:conditions => ["active = ? AND deleted = ? AND start_date <= ? AND  end_date >= ?", true, false, Time.zone.now, Time.zone.now]}}
    named_scope :active_not_deleted, :conditions => ["active = ? AND deleted = ?", true, false]
    named_scope :display_index, :conditions => ["display_index = ? ", true]

    has_many :campaigns_products, :dependent => :destroy
    has_many :products, :through => :campaigns_products
    has_many :active_products, :through => :campaigns_products, :conditions => "campaigns_products.active = 1", :source => 'product'
    has_many :campaigns_categories_products
    has_many :future_events, :as => :changable

    validates_presence_of :name, :title

    MINIMUM_CATEGORY_SIZE  =  8

    def cats
      products.collect{|p|p.categories}.flatten.uniq.sort{|a,b| a.id <=> b.id}
    end

    def products_by_category
      pbc = {}
      active_products.each do |prod|
        prod.categories.each do |categ|
          if pbc[categ.id]
            pbc[categ.id] << prod.id unless pbc[categ.id].include?(prod.id)
          else
            pbc[categ.id] = [prod.id]
          end 
        end
      end
      pbc
    end

    def current?
      now = Time.zone.now
      active && !deleted &&  start_date <= now && end_date >= now
    end

    def self.find_active_by_title(title)
      campaigns = self.find_all_by_title(title)
      campaigns.detect{ |c| c.current? } 
    end

    def find_combined_categories
      Rails.cache.fetch("#{self.id}-combined_categories", :expires_in => 1.hours) do
        ccp = CampaignsCategoriesProduct.find_by_campaign_id(id)
        ccp.nil? ? [] : YAML::load(ccp.yamlized_category_tree) 
      end
    end

    def combine_to_minimum_size(minsize)
      minsize = MINIMUM_CATEGORY_SIZE if minsize.nil?
      pbc = products_by_category
      Category.top_level_present_categories.each do |cat|
        cat.move_in_with_parent_if_need_be(pbc,minsize)
      end
      pbc #.collect{|c|c.empty? ? c : nil}.compact    
    end

    def persist_categories(category_tree)
      CampaignsCategoriesProduct.delete_all("campaign_id = #{id}")
      CampaignsCategoriesProduct.new(
       { :campaign_id => id,
         :yamlized_category_tree =>  category_tree.to_yaml
       }).save
    end

    def product_ids
      products.collect{ |p| p.id }.uniq.sort
    end

    def self.future_change_times
      campaigns = find(:all)
      future_changes = []
      now = Time.zone.now
      campaigns.each do |c|
        future_changes << [c.start_date, c.id] if c.start_date > now
        future_changes << [c.end_date, c.id] if c.end_date > now
      end
      future_changes.sort
    end

  end
  
end