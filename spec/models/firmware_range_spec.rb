require 'spec_helper'

describe FirmwareRange do
  subject { FirmwareRange.new }
  its(:active) { should be_true }
end
