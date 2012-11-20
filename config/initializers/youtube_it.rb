# adds time parameter support to videos search.
# The time parameter restricts the search to videos uploaded within the specified time. 
# Valid values for this parameter are today (1 day), this_week (7 days), this_month (1 month) and all_time. The default value for this parameter is all_time.
# === Example:
#   client.videos_by(:author => 'sizzix', :order_by => 'published', :time => 'this_week').videos #=> returns this weeks recently uploaded videos 
#
class YouTubeIt
  module Parser

    class VideoFeedParser < FeedParser

    protected
      def parse_entry(entry)
        video_id = entry.at("id").text
        published_at = entry.at("published") ? Time.parse(entry.at("published").text) : nil
        uploaded_at = entry.at_xpath("media:group/yt:uploaded") ? Time.parse(entry.at_xpath("media:group/yt:uploaded").text) : nil
        updated_at = entry.at("updated") ? Time.parse(entry.at("updated").text) : nil
        recorded_at = entry.at_xpath("yt:recorded") ? Time.parse(entry.at_xpath("yt:recorded").text) : nil

        # parse the category and keyword lists
        categories = []
        keywords = []
        entry.css("category").each do |category|
          # determine if  it's really a category, or just a keyword
          scheme = category["scheme"]
          if (scheme =~ /\/categories\.cat$/)
            # it's a category
            categories << YouTubeIt::Model::Category.new(
                            :term => category["term"],
                            :label => category["label"])

          elsif (scheme =~ /\/keywords\.cat$/)
            # it's a keyword
            keywords << category["term"]
          end
        end

        title = entry.at("title").text
        html_content = nil #entry.at("content") ? entry.at("content").text : nil

        # parse the author
        author_element = entry.at("author")
        author = nil
        if author_element
          author = YouTubeIt::Model::Author.new(
                     :name => author_element.at("name").text,
                     :uri => author_element.at("uri").text)
        end
        media_group = entry.at_xpath('media:group')

        ytid = nil
        unless media_group.at_xpath("yt:videoid").nil?
          ytid = media_group.at_xpath("yt:videoid").text
        end

        # if content is not available on certain region, there is no media:description, media:player or yt:duration
        description = ""
        unless media_group.at_xpath("media:description").nil?
          description = media_group.at_xpath("media:description").text
        end

        # if content is not available on certain region, there is no media:description, media:player or yt:duration
        duration = 0
        unless media_group.at_xpath("yt:duration").nil?
          duration = media_group.at_xpath("yt:duration")["seconds"].to_i
        end

        # if content is not available on certain region, there is no media:description, media:player or yt:duration
        player_url = ""
        unless media_group.at_xpath("media:player").nil?
          player_url = media_group.at_xpath("media:player")["url"]
        end

        unless media_group.at_xpath("yt:aspectRatio").nil?
          widescreen = media_group.at_xpath("yt:aspectRatio").text == 'widescreen' ? true : false
        end

        media_content = []
        media_group.xpath("media:content").each do |mce|
          media_content << parse_media_content(mce)
        end

        # parse thumbnails
        thumbnails = []
        media_group.xpath("media:thumbnail").each do |thumb_element|
          # TODO: convert time HH:MM:ss string to seconds?
          thumbnails << YouTubeIt::Model::Thumbnail.new(
                          :url    => thumb_element["url"],
                          :height => thumb_element["height"].to_i,
                          :width  => thumb_element["width"].to_i,
                          :time   => thumb_element["time"],
                          :name   => thumb_element["name"])
        end

        rating_element = entry.at_xpath("gd:rating") rescue nil
        extended_rating_element = entry.at_xpath("yt:rating")

        rating = nil
        if rating_element
          rating_values = {
            :min         => rating_element["min"].to_i,
            :max         => rating_element["max"].to_i,
            :rater_count => rating_element["numRaters"].to_i,
            :average     => rating_element["average"].to_f
          }

          if extended_rating_element
            rating_values[:likes] = extended_rating_element["numLikes"].to_i
            rating_values[:dislikes] = extended_rating_element["numDislikes"].to_i
          end

          rating = YouTubeIt::Model::Rating.new(rating_values)
        end

        if (el = entry.at_xpath("yt:statistics"))
          view_count, favorite_count = el["viewCount"].to_i, el["favoriteCount"].to_i
        else
          view_count, favorite_count = 0,0
        end

        comment_feed = entry.at_xpath('gd:comments/gd:feedLink[@rel="http://gdata.youtube.com/schemas/2007#comments"]') rescue nil
        comment_count = comment_feed ? comment_feed['countHint'].to_i : 0

        access_control = entry.xpath('yt:accessControl').map do |e|
          { e['action'] => e['permission'] }
        end.compact.reduce({},:merge)

        noembed     = entry.at_xpath("yt:noembed") ? true : false
        safe_search = entry.at_xpath("media:rating") ? true : false

        if entry.namespaces['xmlns:georss'] and where = entry.at_xpath("georss:where")
          position = where.at_xpath("gml:Point").at_xpath("gml:pos").text
          latitude, longitude = position.split.map &:to_f
        end

        if entry.namespaces['xmlns:app']
          control = entry.at_xpath("app:control")
          state = { :name => "published" }
          if control && control.at_xpath("yt:state")
            state = {
              :name        => control.at_xpath("yt:state")["name"],
              :reason_code => control.at_xpath("yt:state")["reasonCode"],
              :help_url    => control.at_xpath("yt:state")["helpUrl"],
              :copy        => control.at_xpath("yt:state").text
            }
          end
        end

        insight_uri = (entry.at_xpath('xmlns:link[@rel="http://gdata.youtube.com/schemas/2007#insight.views"]')['href'] rescue nil)

        perm_private = media_group.at_xpath("yt:private") ? true : false

        YouTubeIt::Model::Video.new(
          :video_id       => video_id,
          :published_at   => published_at,
          :updated_at     => updated_at,
          :uploaded_at    => uploaded_at,
          :recorded_at    => recorded_at,
          :categories     => categories,
          :keywords       => keywords,
          :title          => title,
          :html_content   => html_content,
          :author         => author,
          :description    => description,
          :duration       => duration,
          :media_content  => media_content,
          :player_url     => player_url,
          :thumbnails     => thumbnails,
          :rating         => rating,
          :view_count     => view_count,
          :favorite_count => favorite_count,
          :comment_count  => comment_count,
          :access_control => access_control,
          :widescreen     => widescreen,
          :noembed        => noembed,
          :safe_search    => safe_search,
          :position       => position,
          :latitude       => latitude,
          :longitude      => longitude,
          :state          => state,
          :insight_uri    => insight_uri,
          :unique_id      => ytid,
          :perm_private   => perm_private)
      end

    end

    class PlaylistFeedParser < FeedParser #:nodoc:

      def parse_content(content)
        xml = REXML::Document.new(content.body)
        entry = xml.elements["entry"] || xml.elements["feed"]
        YouTubeIt::Model::Playlist.new(
          :title         => entry.elements["title"].text,
          :summary       => ((entry.elements["summary"] || entry.elements["media:group"].elements["media:description"]).text rescue ""),
          :description   => ((entry.elements["summary"] || entry.elements["media:group"].elements["media:description"]).text rescue ""),
          :playlist_id   => entry.elements["id"].text[/playlist([^<]+)/, 1].sub(':',''),
          :published     => entry.elements["published"] ? entry.elements["published"].text : nil,
          :response_code => content.status,
          :xml           => content.body)
      end
    end
  end

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



