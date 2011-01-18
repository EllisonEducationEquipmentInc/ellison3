module Feedzirra
  
  module Parser
    class RSSEntry
      element :"atom:summary", :as => :summary
    end
  end
end