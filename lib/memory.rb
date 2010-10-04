require 'rubygems'
require 'sunspot'

module Memory
  class InstanceAdapter < Sunspot::Adapters::InstanceAdapter
    def id
      @instance.id
    end
  end

  class DataAccessor < Sunspot::Adapters::DataAccessor
    def load( id )
      @clazz.find(id)
    end

    def load_all( ids )
      @clazz.find_all(ids.map { |id| id })
    end
  end
end