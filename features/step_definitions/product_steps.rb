Given /^the following products:$/ do |products|
  Product.create!(products.hashes)
end

When /^I delete the (\d+)(?:st|nd|rd|th) product$/ do |pos|
  visit products_path
  within("table tr:nth-child(#{pos.to_i+1})") do
    click_link "Destroy"
  end
end

Then /^I should see the following products:$/ do |expected_products_table|
  expected_products_table.diff!(tableish('table tr', 'td,th'))
end

Given /^a newly initialized product$/ do
  @product = Product.new
end

Given /^I should not be able to save product$/ do
  assert !@product.save
end

Then /^code should raise StandardError$/ do
  pending # express the regexp above with the code you wish you had
end

