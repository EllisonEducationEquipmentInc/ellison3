require 'spec_helper'

describe Firmware do
  subject { Firmware.new }
  its(:display_order) { should eql(100) }
end
