FactoryGirl.define  do
  factory :store do
    sequence(:name) {|i| "Store#{i}" }
    sequence(:store_number) {|i| "000#{i}" }
    product_line ["sizzix", "eclipse"]
    brands ["sizzix", "ellison"]
    agent_type "Authorized Reseller"
    address1 "10191 S De Anza Blvd, CA 95014"
    address2 "Some new address"
    state "California"
    city "Cupertino"
    country "United States"
    phone "999 5555 55"
    fax "999 5555 555"
    email "my_email@mail.com"
    website "www.example.com"
    zip_code "95014"
  end

  factory :all_system_store, parent: :store do
    active true
    systems_enabled %w[szus szuk eeus eeuk erus]
  end

  factory :physical_us_store, parent: :all_system_store do
    physical_store true
  end

  factory :sales_representative_physical_us_store, parent: :physical_us_store do
    agent_type 'Sales Representative'
    representative_serving_states ["Al", "Fl"]
  end

  factory :sales_representative_webstore_us_store, parent: :all_system_store do
    webstore true
    physical_store false
    agent_type 'Sales Representative'
    representative_serving_states ["Al", "Fl"]
  end
end

