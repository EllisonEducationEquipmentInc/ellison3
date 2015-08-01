require 'event_calendar'

module IndexHelper
  include EventCalendar::CalendarHelper

  def month_link(month_date)
    link_to(I18n.localize(month_date, :format => "%B"), {:month => month_date.month, :year => month_date.year})
  end

  # custom options for this calendar
  def event_calendar_options
    {
      :year => @year,
      :month => @month,
      :event_strips => @event_strips,
      :month_name_text => I18n.localize(@shown_month, :format => "%B %Y"),
      :previous_month_text => "<< " + month_link(@shown_month.prev_month),
      :next_month_text => month_link(@shown_month.next_month) + " >>"
    }
  end

  def event_calendar
    calendar event_calendar_options do |args|
      event = args[:event]
      link_to event.name, catalog_path(:anchor => "facets=#{event.facet_param}&ideas=1")
    end
  end

  def store_locator_title
    if is_sizzix_us? || is_ee_us?
      "Store Locator"
    elsif is_uk?
      "Stockist List"
    elsif is_er?
      "Distributor Locator"
    else
      "Store Locator"
    end
  end

  def store_locator_tab
    link_title = if is_sizzix_us? || is_ee_us?
      "Stores"
    elsif is_sizzix_uk? || is_ee_uk?
      "Stockist List"
    elsif is_er?
      "Distributors"
    else
      "Stores"
    end

    link_to link_title, "#stores"
  end

  def additional_text_for store
    if store.catalog_company && !store.webstore
      content_tag(:span, "Contact store to request a catalog", :class => "nav_clearance")
    elsif store.catalog_company && store.webstore
      content_tag(:span, "Online and Catalog", :class => "nav_clearance")
    end
  end

  def retailers_group_with online_retailers, country_array
    if is_ee_uk? || is_sizzix_uk?
      online_retailers.where(:country.in => country_array).order_by(:country => :asc)
    elsif is_ee_us? || is_sizzix_us? ||  is_er_us?
      online_retailers.where(:country.in => country_array).order_by(:country => :desc)
    else
      [ ]
    end
  end

  def retailers_group_without online_retailers, country_array
    online_retailers.where(:country.nin => country_array).order_by(:country => :asc)
  end

  def map_position_for index, store, state
    representative_location = store.representative_serving_states_locations[ state ]
    location = representative_location.present? ? representative_location : store.location
    { :id => index, :point => { :lat => location[0], :lng => location[1] }, :category => 'Stores' }.to_json
  end

  def class_for_zip_option
    is_sizzix_us? || is_sizzix_uk? ? "" : "hide"
  end

  # returns the video id of a Yt::Models::PlaylistItem
  def yt_video_url(video)
    video.snippet.data["resourceId"].try(:[], "videoId")
  end

  # returns the default url of a Yt::Models::PlaylistItem
  def video_default_image(video)
    if video.snippet.data["thumbnails"]
      video.snippet.data["thumbnails"]["default"].try(:[], "url")
    else
      "https://i.ytimg.com/vi/#{yt_video_url(video)}/default.jpg"
    end
  end
end
