module OldData
  class LandingPage < ActiveRecord::Base
  	named_scope :exact_match, :conditions => ['exact_match = ?', true]
  	named_scope :word_match, :conditions => ['exact_match = ?', false]
  	named_scope :active, :conditions => ['active = ? AND deleted = ?', true, false]
  	named_scope :not_deleted, :conditions => ['deleted = ?', false]
	
  	def destroy
    	update_attribute :deleted, true
    end
  end
end
