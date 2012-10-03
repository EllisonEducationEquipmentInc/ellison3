require 'factory_girl_rails'

puts 'Setting up default admin user'
first_admin = Admin.create!(name: "first admin", email: "first_admin@example.com",
	password: "testtest1", employee_number: "1234567", active: true)
puts "first admin user name created: #{first_admin.name}"
puts "first admin email created: #{first_admin.email}"

Permission::ADMIN_MODULES.each{|permission| first_admin.permissions.build(name: permission, systems_enabled: first_admin.systems_enabled, write: true).save}

first_store = FactoryGirl.create(:store, systems_enabled: first_admin.systems_enabled)
puts "Store created: #{first_store.name}"

first_country = FactoryGirl.create(:country, name: "United States", systems_enabled: first_admin.systems_enabled)
second_country = FactoryGirl.create(:country, name: "United Kingdom",systems_enabled: first_admin.systems_enabled)

puts "Country created: #{first_country.name}"
puts "Country created: #{second_country.name}"