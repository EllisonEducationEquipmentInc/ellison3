FactoryGirl.define  do
  factory :store do
    sequence(:name) {|i| "Store#{i}" }
    sequence(:store_number) {|i| "000#{i}" }
    brands ["sizzix", "ellison"]
    agent_type "Authorized Reseller"
    address1 "Mountain View, CA 94040"
    city "San Francisco"
    country "Estados Unidos"
    website "www.example.com"
  end

  factory :all_system_store, parent: :store do
    active true
    systems_enabled %w[szus szuk eeus eeuk erus]
  end
end