module OldData
  class Account < ActiveRecord::Base
    validates_presence_of :address, :city, :zip, :country, :school#, :phone, :fax, :title
    validates_presence_of :state, :if => Proc.new{|p| p.country == 'United States'}
    validates_presence_of :tax_exempt_number, :if => Proc.new(&:tax_exempt)
    # belongs_to :logo, :class_name => "Logo", :foreign_key => "logo_id", :validate => true
    belongs_to :institution
    has_many :users

    named_scope :not_new, :conditions => ['axapta_id != ?', 'new']
    named_scope :available, :conditions => ['active = ? AND deleted = ?', true, false]
    named_scope :not_deleted, :conditions => ['deleted = ?', false]
    
  end
end