class EcalActivation
  include Mongoid::Document
  include Mongoid::Timestamps

  attr_accessor :email_confirmation

  field :first_name
  field :last_name
  field :email
  field :activation_code, default: ''

  validates :first_name, :last_name, :email, :activation_code, :presence => true
  validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  validates :activation_code, :format => { :with => /[A-Za-z]{4}-\d{5}-\d{5}-\d{5}-\d{5}/ }

  def activation_code_1
    self.activation_code[0,4]
  end

  def activation_code_2
    self.activation_code[5,5]
  end

  def activation_code_3
    self.activation_code[11,5]
  end

  def activation_code_4
    self.activation_code[17,5]
  end

  def activation_code_5
    self.activation_code[23,5]
  end
end
