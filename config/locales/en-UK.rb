{
  :'en-UK' => {
    :date => {
      :formats => {
        :default => "%d/%m/%Y",
        :short => "%e %b",
        :long => "%e %B, %Y",
        :long_ordinal => lambda { |date| "#{date.day.ordinalize} %B, %Y" },
        :only_day => "%e"
      },
      :day_names => Date::DAYNAMES,
      :abbr_day_names => Date::ABBR_DAYNAMES,
      :month_names => Date::MONTHNAMES,
      :abbr_month_names => Date::ABBR_MONTHNAMES,
      :order => [:year, :month, :day]
    },
    :time => {
      :formats => {
        :home_xml => "%Y-%m-%d %H:%M",
        :default => "%a %b %d %H:%M:%S %Z %Y",
        :date => "%d/%m/%Y",
        :date_short => "%d %b, %Y",
        :time => "%H:%M",
        :short => "%d %b %H:%M",
        :day_month => "%d %b",
        :custom => "%d/%m/%Y %H:%M",
        :blog => "%A, %e %B, %Y",
        :long => "%d %B, %Y %H:%M",
        :long_ordinal => lambda { |time| "#{time.day.ordinalize} %B, %Y %H:%M" },
        :only_second => "%S"
      },
      :datetime => {
        :formats => {
          :default => "%Y-%m-%dT%H:%M:%S%Z"
        }
      },
      :time_with_zone => {
        :formats => {
          :default => lambda { |time| "%Y-%m-%d %H:%M:%S #{time.formatted_offset(false, 'UTC')}" }
        }
      },
      :am => 'am',
      :pm => 'pm'
    },
    :datetime => {
      :distance_in_words => {
        :half_a_minute => 'half a minute',
        :less_than_x_seconds => {:zero => 'less than a second', :one => 'less than a second', :other => 'less than {{count}} seconds'},
        :x_seconds => {:one => '1 second', :other => '{{count}} seconds'},
        :less_than_x_minutes => {:zero => 'less than a minute', :one => 'less than a minute', :other => 'less than {{count}} minutes'},
        :x_minutes => {:one => "1 minute", :other => "{{count}} minutes"},
        :about_x_hours => {:one => 'about 1 hour', :other => 'about {{count}} hours'},
        :x_days => {:one => '1 day', :other => '{{count}} days'},
        :about_x_months => {:one => 'about 1 month', :other => 'about {{count}} months'},
        :x_months => {:one => '1 month', :other => '{{count}} months'},
        :about_x_years => {:one => 'about 1 year', :other => 'about {{count}} years'},
        :over_x_years => {:one => 'over 1 year', :other => 'over {{count}} years'}
      }
    },
    :number => {
      :format => {
        :precision => 2,
        :separator => '.',
        :delimiter => ','
      },
      :currency => {
        :format => {
          :unit => '£',
          :precision => 2,
          :format => '%u%n'
        }
      }
    },
 
    :activemodel => {
      :errors => {
        :template => {
          :header => {
            :one => "1 error prohibited this {{model}} from being saved",
            :other =>  "{{count}} errors prohibited this {{model}} from being saved."
          },
          :body => "There were problems with the following fields:"
        },
        :messages => {
          :accepted => "must be accepted",
          :blank => "can't be blank",
          :confirmation => "doesn't match confirmation",
          :empty => "can't be empty",
          :equal_to => "must be equal to {{count}}",
          :even => "must be even",
          :exclusion => "is reserved",
          :greater_than => "must be greater than {{count}}",
          :greater_than_or_equal_to => "must be greater than or equal to {{count}}",
          :inclusion => "is not included in the list",
          :invalid => "is invalid",
          :less_than => "must be less than {{count}}",
          :less_than_or_equal_to => "must be less than or equal to {{count}}",
          :not_a_number => "is not a number",
          :odd => "must be odd",
          :taken => "is already taken",
          :too_long => "is too long (maximum is {{count}} characters)",
          :too_short => "is too short (minimum is {{count}} characters)",
          :wrong_length => "is the wrong length (should be {{count}} characters)"
        }
      }
    }
  }
}