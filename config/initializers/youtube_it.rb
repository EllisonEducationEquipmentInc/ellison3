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
end


