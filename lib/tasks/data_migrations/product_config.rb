module OldData
  class ProductConfig < ActiveRecord::Base
    named_scope :active, :conditions => ['active = ? AND deleted = ?', true, false]
    named_scope :deleted, :conditions => ['deleted = ?', true]
    named_scope :inactive, :conditions => ['active = ?', false]
    named_scope :in_group, lambda { |param| { :conditions => ["config_group = ?", param], :order => "name" } }
    named_scope :nogroup, :conditions => ['config_group IS NULL'], :order => "name" 
    named_scope :not_deleted, :conditions => ["deleted = ?", false]

    after_save :clear_grouped_options

    validates_presence_of :name

    has_many :products

  	def self.distinct_config_groups
  		Rails.cache.fetch("distinct_config_groups", :expires_in => 3.hours) do
  			active.all(:select => "DISTINCT config_group").map {|c| c.config_group}
  		end
  	end

    def self.grouped_options
      Rails.cache.fetch("grouped_options", :expires_in => 3.hours) do
        grouped_options = {"no option" => [["no config for this product", nil]]}
        groups = active(:all, :select => "DISTINCT config_group")
        groups.each do |g|
          if g.config_group
            grouped_options[g.config_group] = active.in_group(g.config_group).map {|m| ["#{m.additional_name} (#{m.id})", m.id]}
          else
            grouped_options["none"] = active.nogroup.map {|m| ["#{m.additional_name} (#{m.id})", m.id]}
          end
        end
        grouped_options["inactive"] = inactive.map {|m| ["#{m.additional_name} (#{m.id})", m.id]}
        grouped_options["deleted"] = deleted.map {|m| ["#{m.additional_name} (#{m.id})", m.id]}
        grouped_options
      end
    end

    def destroy
    	update_attribute :deleted, true
    end

  private
    def clear_grouped_options
      Rails.cache.delete("grouped_options")
      return
    end
  end
end