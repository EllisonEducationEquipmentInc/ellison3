require File.expand_path(File.dirname(__FILE__) + '/polymorphic_tag')

module OldData
  class Idea < ActiveRecord::Base

    attr_accessor :to_reindex

    #acts_as_ferret :fields => [:idea_num, :name] 
    #after_save :flush_cache
    after_create :clear_all_ideas
    after_save {|record| record.index! rescue '' if record.to_reindex == "1"}

    named_scope :available, lambda {{:conditions => ["active_status = ? AND start_date <= ? AND  end_date >= ?", true, Time.zone.now, Time.zone.now]}}
    named_scope :new_idea, lambda { { :conditions => ['new_lesson = ? AND new_expires_at > ?', true, Time.zone.now ] } }
    named_scope :id_only, :select => "id, artist_id"

    belongs_to :artist
    has_and_belongs_to_many       :themes
    has_and_belongs_to_many       :tags
    has_and_belongs_to_many       :products, :join_table => "products_ideas", :validate => false
    has_and_belongs_to_many :idea_catalogs

    has_and_belongs_to_many       :cross_ideas,
                                      :join_table => 'cross_ideas',
                                      :foreign_key => 'idea_id',
                                      :association_foreign_key => 'cross_idea_idea_id',
                                      :class_name => 'Idea',
                                      :order => 'idea_id'

    has_many :idea_tabs_ideas, :order => "display_order, id", :dependent => :destroy
    has_many :idea_tabs, :through => :idea_tabs_ideas, :order => "idea_tabs_ideas.display_order, idea_tabs_ideas.id", :uniq => true
    #has_and_belongs_to_many :curriculums, :validate => false


    # =====validations =====
    validates_presence_of  :name
    validates_uniqueness_of :idea_num
    validates_numericality_of :idea_num

  	has_and_belongs_to_many :polymorphic_tags

  	# create polymorphic_tags association methods by name with "poly_" prefix: @idea.poly_categories #=> Array of associated "category" polymorphic_tags
  	PolymorphicTag::TYPES.values.each do |e|
  		class_eval "def poly_#{e.to_s.pluralize}\n  polymorphic_tags.available.send(\"#{e.to_s.pluralize}\") \n end"
  	end

    def myideaname
      "[" + "#{idea_num}" + "]" + " #{name}"
    end

    def available?
      active_status == "1" && start_date <= Time.zone.now && end_date >= Time.zone.now
    end

  	def active
  		active_status == "1"
  	end

  	def primary_key
  		id
  	end

  	def effective_life_cycle
  		"New" if new_lesson && !new_expires_at.blank? && Time.zone.now < new_expires_at
  	end

  	def stored(method_name)
  		method_name = :name if method_name == :stored_name
  		send method_name
  	end


  private
    def clear_all_ideas
      Rails.cache.delete("all_ideas")
      return
    end
  end
  
end