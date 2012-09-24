require 'spec_helper'

describe SharedContent do
  subject { SharedContent.new }
  its(:display_order) { should eql(100) }
end
