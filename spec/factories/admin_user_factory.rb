FactoryGirl.define  do
  factory :admin_user, class: Admin do
    sequence(:email) {|i| "admin#{i}@example.com" }
    sequence(:employee_number){|i| "1234567#{i}" }
    sequence(:name) {|i| "foo#{i}" }
    password "foo1foo1"
    active true
  end
end