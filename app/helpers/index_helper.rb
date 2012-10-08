module IndexHelper
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
    if is_us?
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
    end
  end

  def retailers_group_without online_retailers, country_array
    online_retailers.where(:country.nin => country_array).order_by(:country => :asc)
  end

end
