class FirmwareRange
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :active, :type => Boolean, :default => true
  field :prefix
  field :start_from
  field :end_to
  
  validates_presence_of :prefix, :start_from, :end_to
  validates_format_of :prefix, :with => /^[a-z]{1}((0\d)|(1[0-2]{1}))$/i, :message => "is invalid. Format: XNN  Example: B02"
  validates_format_of :start_from, :end_to, :with => /^\d{4}$/, :message => "is invalid. Format: NNNN Example: 0001)"

  scope :active, :where => { :active => true }

  def self.valid?(serial_number)
    return false unless serial_number =~ /^[a-z]{1}((0\d)|(1[0-2]{1}))\d{4}$/i
    active.find_all_by_prefix(serial_number[0,3]).any? {|r| r.to_range.include?(serial_number[3,8].to_i)}
  end

  def to_range
    start_from.to_i..end_to.to_i
  end

  def prefix=(p)
    write_attribute(:prefix, p.upcase)
  end

  def destroy
    update_attribute :active, false
  end

private

  def validate
    errors.add :invalid_range, "'End to' has to be greater than 'Start from'" if read_attribute('start_from').to_i >= read_attribute('end_to').to_i
  end
end
