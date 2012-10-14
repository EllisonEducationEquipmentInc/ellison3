module Feedzirra
  
  module Parser
    class RSSEntry
      element :"atom:summary", :as => :summary, :with => {:type => "text"}
    end
    
    class RSS
      element :"openSearch:totalResults", :as => :total_results
    end
    
    class Atom
      element :"openSearch:totalResults", :as => :total_results
    end
  end
end
