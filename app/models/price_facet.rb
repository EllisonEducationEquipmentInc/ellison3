require 'singleton'

class PriceFacet
  include Singleton
  include EllisonSystem

  AbstractFacet = Struct.new(:label, :min, :max, :saving)

  def initialize

  end

  def facets(outlet=false)
    if outlet
      [AbstractFacet.new("Under #{c}1.00", 0, 1), AbstractFacet.new("#{c}1.00 to #{c}4.99", 1, 5), AbstractFacet.new("#{c}5.00 to #{c}9.99", 5, 10), AbstractFacet.new("#{c}10.00 to #{c}14.99", 10, 15), AbstractFacet.new("#{c}15.00 to #{c}19.99", 15, 20), AbstractFacet.new("#{c}20.00 to #{c}49.99", 20, 50), AbstractFacet.new("#{c}50.00+", 50, 9999999)]
    elsif is_ee?
      [AbstractFacet.new("Under #{c}20.00", 0, 20), AbstractFacet.new("Under #{c}60.00", 0, 60), AbstractFacet.new("Under #{c}100.00", 0, 100), AbstractFacet.new("Under #{c}150.00", 0, 150), AbstractFacet.new("Under #{c}300.00", 0, 300), AbstractFacet.new("Under #{c}600.00", 0, 600), AbstractFacet.new("Over #{c}600.00", 600, 9999999)]
    else
      [AbstractFacet.new("Under #{c}5.00", 0, 5), AbstractFacet.new("Under #{c}10.00", 0, 10), AbstractFacet.new("Under #{c}15.00", 0, 15), AbstractFacet.new("Under #{c}25.00", 0, 25), AbstractFacet.new("Under #{c}50.00", 0, 50), AbstractFacet.new("Over #{c}50.00", 50, 9999999)]
    end
  end

  def savings
    [AbstractFacet.new("Under 60%", 0, 59, true), AbstractFacet.new("60% to 74%", 60, 74, true), AbstractFacet.new("75% to 80%", 75, 80, true), AbstractFacet.new("Over 80%", 81, 99, true)]
  end

  def c
    I18n.t :'number.currency.format.unit'
  end

  def get_label(range_text, saving=false, outlet=false)
    if saving
      savings
    else
      facets(outlet)
    end.detect {|e| e.min == range_text.split("~")[0].to_i && e.max == range_text.split("~")[1].to_i}.label
  rescue
    saving ? "#{range_text.split("~")[0]}% to #{range_text.split("~")[1]}%" : "#{c}#{range_text.split("~")[0]} to #{c}#{range_text.split("~")[1]}"
  end
end
