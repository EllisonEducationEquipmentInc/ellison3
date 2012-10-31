class TagFacet < SearchFacet

  attr_accessor :tag

  def initialize(id)
    @tag = id.is_a?(Tag) ? id : Tag.find_by_permalink(*id.split("~"))
  end

  def id
    @tag.facet_param
  end

  def name
    @tag.name
  end

  def method_missing(method_id, *args)
    @tag.send method_id, *args
  end

  def self.find_all(ids)
    h={}
    ids.each {|e| h[e.split("~")[0]].present? ? h[e.split("~")[0]] << e.split("~")[1] : h[e.split("~")[0]] = [e.split("~")[1]]}
    criteria = Mongoid::Criteria.new(Tag)
    h.each {|k,v| criteria = criteria.where(:active => true, :permalink.in => v, :tag_type => k)}
    criteria.map {|e| new(e)}
  end

end
