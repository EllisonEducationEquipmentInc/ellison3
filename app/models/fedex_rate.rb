class FedexRate
  include EllisonSystem
  include Mongoid::Document

	field :weight_min, :type => Float
	field :weight_max, :type => Float
	field :rates, :type => Hash
	
	SERVICES = ["ground", "express_saver", "second_day", "overnight"]
		
	validates :weight_min, :weight_max, :rates, :presence => true
	validates_numericality_of :weight_min, :weight_max
		
	index :weight_min
	index :weight_max
	
	before_save :clean_up_rates
	
	class << self
	  def find_by_weight(weight)
	    where({:weight_min.lte => weight, :weight_max.gte => weight}).first
	  end
	end
	
private
  
  def clean_up_rates
    self.rates.each_value {|e| e.delete_if {|k,v| v.blank?}}.delete_if {|k,v| v.blank?}
    self.rates.each_value {|v| v.floatify_values!}
  end
end
