Feature: Manage systems
  In order to build a global application
  As a user
  I want to be able distinguish different systems
  
  Scenario: Default system is sizzix us
    Given I have no system specified
    And I am on the home page
		Then I should see "sizzix.com"
		And current_system should be szus
		And ActiveRecord::Base classes should have access to current_system method
		
  Scenario: selected system is szuk
    Given I specified the system to be szuk
    And I am on system szuk home page
		Then current_system should be szuk
		And I should see "sizzix.co.uk"
