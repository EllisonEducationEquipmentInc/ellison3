FactoryGirl.define  do
  factory :store do
    sequence(:name) {|i| "Store#{i}" }
    sequence(:store_number) {|i| "000#{i}" }
    brands ["sizzix", "ellison"]
    agent_type "Authorized Reseller"
    address1 "foo address"
    city "San Francisco"
    country "Estados Unidos"
    website "www.example.com"
  end
end