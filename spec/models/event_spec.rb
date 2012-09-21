require 'spec_helper'

describe Event do
  subject { Event.new }
  its(:active) { should be_true }
end
