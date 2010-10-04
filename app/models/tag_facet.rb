class TagFacet < SearchFacet
	
	attr_accessor :tag

	def initialize(id)
		@tag = Tag.find_by_permalink(*id.split("~"))
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
	
end