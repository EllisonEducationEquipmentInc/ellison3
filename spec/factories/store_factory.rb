FactoryGirl.define  do
  factory :store do
    sequence(:name) {|i| "Store#{i}" }
    sequence(:store_number) {|i| "000#{i}" }
    brands ["sizzix", "ellison"]
    agent_type "Authorized Reseller"
    address1 "10191 S De Anza Blvd, CA 95014"
    city "Cupertino"
    country "United States"
    website "www.example.com"
    zip_code "95014"
  end

  factory :all_system_store, parent: :store do
    active true
    systems_enabled %w[szus szuk eeus eeuk erus]
  end
end

