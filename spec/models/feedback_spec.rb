require 'spec_helper'

describe Feedback do
  subject { Feedback.new }
  its(:priority) { should eql(0) }
end
