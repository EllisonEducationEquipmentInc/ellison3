
Given /^I have no system specified$/ do
	set_current_system nil
end

Given /^I specified the system to be (.+)$/ do |arg1|
  set_current_system arg1
end

Then /^current_system should be (.+)$/ do |arg1|
  assert_equal arg1, current_system
end

Then /^(.+) classes should have access to current_system method$/ do |arg1|
  assert_respond_to eval(arg1), :current_system
end

Then /^(.+)\.current_system class method should return (.+)$/ do |arg1, arg2|
  assert_equal eval("#{arg1}.current_system"), arg2
end


