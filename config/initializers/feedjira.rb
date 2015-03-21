module Feedjira
  
  module Parser
    class RSSEntry
      element :"atom:summary", :as => :summary
    end
    
    class RSS
      element :"openSearch:totalResults", :as => :total_results
    end
    
    class Atom
      element :"openSearch:totalResults", :as => :total_results
      element :"yt:playlistId", :as => :yt_playlist_id
    end
    
    class AtomEntry
      element :"yt:playlistId", :as => :yt_playlist_id
    end
  end

  module FeedEntryUtilities
    def as_json(options=nil)
      h={}
      each do |item|
        h[item] = send(item)
      end
      h
    end
  end
end
