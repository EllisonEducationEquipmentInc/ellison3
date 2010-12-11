module OldData
  class Wishlist < ActiveRecord::Base
    belongs_to :user
    has_many :products, :through => :products_wishlists, :order => "products_wishlists.position"
    has_many :products_wishlists, :order => "products_wishlists.position"

    validates_presence_of :user_id, :name

    named_scope :active, :conditions => ['wishlists.deleted = ?', false]
    # named_scope :public, :conditions => ['wishlists.public = ?', true]
    # named_scope :default, :conditions => ['wishlists.default = ?', true]

  	before_save :set_premalink

  	# custom attribute names in error messages
    HUMANIZED_ATTRIBUTES = {
       :name => "List Name"
    }
    def self.human_attribute_name(attr)
      HUMANIZED_ATTRIBUTES[attr.to_sym] || super
    end

    def next_position
      products_wishlists.map {|pw| pw.position}.compact.sort {|y,x| x <=> y}.first + 1 rescue 1
    end

  protected  
    def validate
      errors.add('product', "is already in #{name}.") if  products_wishlists.select {|pw| pw.new_record?}.any? {|n| products.include?(n.product)}
    end

  	def set_premalink
  		self.permalink ||= Digest::SHA1.hexdigest("sizzixwishlist#{rand}#{Time.zone.now}")
  	end
  end
  
end