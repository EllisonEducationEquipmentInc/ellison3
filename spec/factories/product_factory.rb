FactoryGirl.define  do
  factory :product do
    sequence(:name) {|i| "foo_product_name#{i}" }
    sequence(:item_num){|i| "123#{i}" }
    msrp_usd 222.2
    systems_enabled ["szus"]
    item_type "bundle"
    item_group "Sizzix"
    life_cycle "pre-release"
    start_date_szus "Tue, 25 Sep 2012 00:00:00 PDT -07:00"
    end_date_szus "Tue, 25 Sep 2013 00:00:00 PDT -07:00"
  end
end