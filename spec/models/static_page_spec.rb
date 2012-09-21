require 'spec_helper'

describe StaticPage do
  subject { StaticPage.new }
  its(:active) { should be_true }
end
