# adds time parameter support to videos search.
# The time parameter restricts the search to videos uploaded within the specified time. 
# Valid values for this parameter are today (1 day), this_week (7 days), this_month (1 month) and all_time. The default value for this parameter is all_time.
# === Example:
#   client.videos_by(:author => 'sizzix', :order_by => 'published', :time => 'this_week').videos #=> returns this weeks recently uploaded videos 
#
class YouTubeIt
  module Request #:nodoc:
    class VideoSearch < BaseSearch #:nodoc:
      attr_reader :time
    
    private
      def to_youtube_params
        {
          'max-results' => @max_results,
          'orderby' => @order_by,
          'start-index' => @offset,
          'vq' => @query,
          'alt' => @response_format,
          'format' => @video_format,
          'racy' => @racy,
          'author' => @author,
          'time' => @time
        }
      end
    end
  end
  
  module Response
    class VideoSearch < YouTubeIt::Record
      attr_accessor :offset
      
      def page
        @page || current_page
      end
      
      def page=(p)
        @offset = (p-1) * max_result_count + 1
        @page = p
      end
      
      def max_result_count=(c)
        @max_result_count = c
      end
    end
  end
  
  # hack to be able to pull more than 25 videos of a list, and enabling pagination
  module Model
    class Playlist < YouTubeIt::Record
      attr_reader :title, :description, :summary, :playlist_id, :xml, :published, :response_code
      
      delegate :max_result_count, :max_result_count=, :current_page, :total_result_count, :next_page, :previous_page, :total_pages, :offset, :page=, :to => :videos_feed
      
      def videos_feed
        @videos_feed ||= YouTubeIt::Parser::VideosFeedParser.new("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2").parse
      end
      
      def videos(page = current_page)
        YouTubeIt::Parser::VideosFeedParser.new("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2&max-results=#{max_result_count}&start-index=#{offset}").parse_videos
      end
    end
  end
end



