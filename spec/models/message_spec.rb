require 'spec_helper'

describe Message do
  subject { Message.new }
  its(:active) { should be_true }
end
