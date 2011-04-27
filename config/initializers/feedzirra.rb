module Feedzirra
  
  module Parser
    class RSSEntry
      element :"atom:summary", :as => :summary
    end
    
    class RSS
      element :"openSearch:totalResults", :as => :total_results
    end
  end
end