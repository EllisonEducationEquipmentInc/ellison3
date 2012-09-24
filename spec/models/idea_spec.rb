require 'spec_helper'

describe Idea do
  subject { Idea.new }
  its(:use_tabs) { should be_true }
end
