class Feed
  include Mongoid::Document
  include Mongoid::Timestamps
  include EllisonSystem
  
  field :name
  field :feeds
  index :name
  
  validates_presence_of :name, :feeds
  
  def entries
    ActiveSupport::JSON.decode(self.feeds) rescue []
  end
end
