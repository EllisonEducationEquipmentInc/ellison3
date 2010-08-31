require 'test_helper'

class AddressTest < ActiveSupport::TestCase
  should "be valid" do
    assert Address.new.valid?
  end
end
