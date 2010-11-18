require 'singleton'

class RetailerDiscountLevels
  include Singleton 

  DiscountLevel = Struct.new(:id, :name, :group)
  
  attr_reader :levels, :groups, :grouped_hash
  
  def initialize
    @levels = []
    {
          1 => ["Dealer", "Sizzix"],
          2 => ["Preferred Dealer", "Sizzix"],
          3 => ["Executive Dealer", "Sizzix"],
          4 => ["Elite Dealer", "Sizzix"],
          5 => ["Buying Group", "Sizzix"],
          6 => ["Key Account", "Sizzix"],
          7 => ["Distributor", "Sizzix"],
          8 => ["Sales Rep", "Sizzix"],
          9 => ["Dealer", "International"],
          10 => ["Preferred Dealer", "International"],
          11 => ["Executive Dealer", "International"],
          12 => ["Elite Dealer", "International"],
          13 => ["Buying Group", "International"],
          14 => ["Key Account", "International"],
          15 => ["Distributor", "International"],
          16 => ["Sales Rep", "International"],
          17 => ["No Stock Dealer", "Education"],
          18 => ["Stocking Dealer", "Education"],
          19 => ["5K Dealer", "Education"],
          20 => ["10K Dealer", "Education"],
          21 => ["15K Dealer", "Education"],
          22 => ["Key Account", "Education"],
          23 => ["Catalog Dealer/Distributor", "Education"],
          24 => ["Sales Rep", "Education"]
        }.each do |k,v|
      
      @levels << DiscountLevel.new(k, v[0], v[1])
    end
    @groups = @levels.map {|e| e.group}.uniq
    @grouped_hash = {}
    @groups.each do |group|
      @grouped_hash[group] = find_by_group(group).map {|e| [e.name, e.id]}
    end
  end
  
  def find(id)
    @levels.detect {|e| e.id == id}
  end
  
  def find_by_group(group)
    @levels.select {|e| e.group == group}
  end
  
  alias :[] :find

end