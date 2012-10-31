require 'memory'
class SearchFacet
  include EllisonSystem

  attr_accessor :id, :name

  class << self
    include EllisonSystem

    def find(id)
      new(id)
    end

    def find_all(ids)
      ids.map {|i| find(i)}
    end
  end
end
