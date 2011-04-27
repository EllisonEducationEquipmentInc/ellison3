class Feed
  include Mongoid::Document
  include Mongoid::Timestamps
  include EllisonSystem
  
  field :name
  field :feeds
  field :total_results, :type => Integer
  
  index :name
  
  validates_presence_of :name, :feeds
  
  def entries
    ActiveSupport::JSON.decode(self.feeds) rescue []
  end
end
