class List
  include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	
	referenced_in :user
	
	validates :name, :user_id, :presence => true
	
	field :name
	field :active, :type => Boolean, :default => true
	field :default_list, :type => Boolean, :default => false
	field :owns, :type => Boolean, :default => false
	field :save_for_later, :type => Boolean, :default => false
	field :product_ids, :type => Array, :default => []
	field :comments
	field :old_permalink
	field :system
	
	index :active
	index :owns
	index :save_for_later
	index :system
	
	index [[:user_id, Mongo::ASCENDING], [:active, Mongo::ASCENDING], [:save_for_later, Mongo::ASCENDING]]
	
	scope :listable, :where => { :active => true,  :save_for_later.ne => true}
	
	before_create :set_system
	
	class << self
	  
	  def most_popular_products(sys = current_system)
	    map = <<EOF 
	      function() {
          if (this.product_ids) {
            this.product_ids.forEach(function(doc) {
              if (doc) emit( doc, 1);
            })
          }
        }
EOF
      
      reduce = <<EOF 
        function( key , values ){
          var total = 0;
          for ( var i=0; i<values.length; i++ )
            total += values[i];
          return total;
        }
EOF
            
      res = collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {:active => true, :save_for_later => {"$ne"=>true}, :owns => {"$ne"=>true}, :system => sys}})["results"]
      res.sort {|x,y| y["value"] <=> x["value"]}[0,10]
	  end
	  
	  def items_per_list(options = {})
	    sys = options[:system] || current_system
	    query = options[:query] || {:active => true, :save_for_later => {"$ne"=>true}, :owns => {"$ne"=>true}, :system => sys}
	    
	    map = <<EOF 
	      function() {
	        emit(this._id, this.product_ids.length)
        }
EOF
      reduce = <<EOF 
        function( key , values ){
          var total = 0;
          for ( var i=0; i<values.length; i++ )
            total += values[i];
          return total;
        }
EOF
	    collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => query})["results"].map {|e| e["value"]}.sort {|x,y| y<=>x}
	  end
    
	end
	
	def products
	  Product.displayable.where(:_id.in => self.product_ids).cache
	end
	
	def add_product(product_id)
	  product_id = BSON::ObjectId(product_id) if product_id.is_a?(String)
	  unless self.product_ids.include?(product_id)
	    self.product_ids << product_id 
	    save
	  end
	end
	
	def destroy
    update_attribute :active, false
  end

private

	def set_system
		self.system ||= current_system
	end
end