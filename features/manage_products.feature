Feature: Manage products
  In order to operate an e-commerce website
  As a user
  I want to be able to manage products
  
  Scenario: Create new blank product
    Given a newly initialized product
    Then I should not be able to save product

  Scenario: Create new product
    Given a newly initialized product
		And something else
    Then I should not be able to save product
