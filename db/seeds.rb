puts 'Setting up default admin user'
first_admin = Admin.create!(name: "first admin", email: "first_admin@example.com",
	password: "testtest1", employee_number: "1234567", active: true)

puts "first admin user name created: #{first_admin.name}"
puts "first admin email created: #{first_admin.email}"

Permission::ADMIN_MODULES.each{|permission| first_admin.permissions.build(name: permission, systems_enabled: first_admin.systems_enabled, write: true).save}