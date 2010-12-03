module OldData
  class Tab < ActiveRecord::Base
    named_scope :available, :conditions => ['active = ? AND deleted = ?', true, false]
    named_scope :has_multi_products, :joins => "JOIN (SELECT tab_id, COUNT(*) AS num_prod  FROM products_tabs GROUP BY tab_id) AS pt ON tabs.id = pt.tab_id", :conditions => "pt.num_prod > 1"
    named_scope :has_single_product, :joins => "JOIN (SELECT tab_id, COUNT(*) AS num_prod  FROM products_tabs GROUP BY tab_id) AS pt ON tabs.id = pt.tab_id", :conditions => "pt.num_prod = 1"
    named_scope :unassigned, :select => "tabs.*", :include => :products, :conditions => "products.id IS NULL"
    named_scope :reusable, :conditions => ['reusable = ?', true]
    named_scope :not_deleted, :conditions => ["deleted = ?", false]

    #@tabs = Tab.all(:joins => "JOIN (SELECT tab_id, COUNT(*) AS num_prod  FROM products_tabs GROUP BY tab_id) AS pt ON tabs.id = pt.tab_id", :conditions => "pt.num_prod > 1")


    has_many :products_tabs, :dependent => :destroy
    has_many :products, :through => :products_tabs, :validate => false

    validates_presence_of :name, :style
    validates_presence_of :freeform, :if => Proc.new {|p| p.style == 1}

    serialize :images, Hash
    serialize :column_grid, Hash
    serialize :item_nums, Hash

    # max number of rows in 4 comlumn grid style
    MAX_GRID = 16
    MAX_INSTRUCTIONS = 12

    STYLES = [
                ["freeform html",1],
                ["2 column image grid",2],
                ["4 column grid",3],
                ["compatibility (5x4)",4],
                ["products (3xn)",5],
                ["ideas (2xn)",6],
                ["products (3xn) + freeform",7]
              ]

    def destroy
    	update_attribute :deleted, true
    end
  end
  
end