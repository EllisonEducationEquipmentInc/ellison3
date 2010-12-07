module OldData
  class IdeaTab < ActiveRecord::Base
    named_scope :available, :conditions => ['active = ? AND deleted = ?', true, false]
    named_scope :has_multi_products, :joins => "JOIN (SELECT idea_tab_id, COUNT(*) AS num_prod  FROM idea_tabs_ideas GROUP BY idea_tab_id) AS pt ON idea_tabs.id = pt.idea_tab_id", :conditions => "pt.num_prod > 1"
    named_scope :has_single_product, :joins => "JOIN (SELECT idea_tab_id, COUNT(*) AS num_prod  FROM idea_tabs_ideas GROUP BY idea_tab_id) AS pt ON idea_tabs.id = pt.idea_tab_id", :conditions => "pt.num_prod = 1"
    named_scope :unassigned, :select => "idea_tabs.*", :include => :ideas, :conditions => "ideas.id IS NULL"
    named_scope :reusable, :conditions => ['reusable = ?', true]
    named_scope :not_deleted, :conditions => ["deleted = ?", false]

    has_many :idea_tabs_ideas, :dependent => :destroy
    has_many :ideas, :through => :idea_tabs_ideas, :validate => false

    validates_presence_of :name, :style
    validates_presence_of :freeform, :if => Proc.new {|p| p.style == 1}

    serialize :images, Hash
    serialize :column_grid, Hash
    serialize :item_nums, Hash

    # max number of rows in 4 comlumn grid style
    MAX_GRID = 16

    STYLES = [
                ["freeform html",1],
                ["2 column image grid",2],
                ["4 column grid",3],
                ["compatibility (5x4)",4],
                ["products (3xn)",5],
                ["ideas (2xn)",6],
                ["products (3xn) + freeform",7]
              ]

    def item_nums
      read_attribute('item_nums').nil? && style == 7 ? {:products => Array.new(24)} : read_attribute('item_nums')
    end

    def destroy
    	update_attribute :deleted, true
    end
  end
  
end