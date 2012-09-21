require 'spec_helper'

describe Report do
  subject { Report.new }
  its(:percent) { should eql(0) }
end
