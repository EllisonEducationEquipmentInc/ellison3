FactoryGirl.define  do
  factory :country do
    sequence(:iso_name) {|i| "iso_name#{i}" }
    sequence(:iso){|i| "iso_#{i}" }
    sequence(:iso3){|i| "iso3_#{i}" }
    sequence(:numcode){|i| "2123_#{i}" }
    sequence(:name){|i| "name_#{i}" }
  end
end