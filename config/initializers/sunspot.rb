module Sunspot
  module Search #:nodoc:
    class AbstractSearch
  		#
  		# ==== Spellcheck extensions (when performing keyword search)
  		#
  		# Note: solr has to be configured properly in order to make spellcheck work. more info: http://wiki.apache.org/solr/SpellCheckComponent#Configuration and http://wiki.apache.org/solr/SpellCheckingAnalysis
  		#
    
    	
  		# <tt>&spellcheck=true&spellcheck.collate=true&spellcheck.build=true</tt> params have to be added to the solr search query. 
  		# ==== Example:
  		#
  		# 		Sunspot.search Post do
  		#				keywords 'great pizza'
  		# 			adjust_solr_params do |params|
  		# 			  params[:"spellcheck"] = true
  		# 				params[:"spellcheck.collate"] = true
  		# 			end
  		# 		end
  		#
  		# (see Sunspot::DSL::Query#adjust_solr_params for details) 
  		def spellcheck_response
  			@spellcheck_response ||= @solr_result["spellcheck"] && @solr_result["spellcheck"]["suggestions"]
  		end
		
  		def correctly_spelled?
  			spellcheck_response && spellcheck_response[spellcheck_response.index("correctlySpelled")+1]
  		end
		
  		# returns suggestions for misspelled words in this format:
  		# example keywords: flover+orignal
  		# 	[{"startOffset"=>0, "endOffset"=>6, "origFreq"=>0, "suggestion"=>[{"word"=>"flower", "freq"=>30}, {"word"=>"flowers", "freq"=>8}], "numFound"=>2}, {"startOffset"=>7, "endOffset"=>14, "origFreq"=>0, "suggestion"=>[{"word"=>"originals", "freq"=>2}], "numFound"=>1}]
  		def spell_suggestions
  			spellcheck_response.select {|a| a.is_a? Hash} rescue nil
  		end
		
  		# Take the best suggestion for each token (if it exists) and construct a new keyword from the suggestions. For example, 
  		# if the input keyword was "jawa class lording" and the best suggestion for "jawa" was "java" and "lording" was "loading", 
  		# then the resulting collation would be "java class loading". Please Note: This only returns a keyword to be used it does not actually run the query.
  		def spell_collation
  			spellcheck_response && spellcheck_response.index("collation") && spellcheck_response[spellcheck_response.index("collation")+1]
  		end
  	end
  end
end

class SunspotCommiter
  def perform
    Sunspot.commit
    Delayed::Job.enqueue self, 0, (Time.now + 1.hour).utc
  end
end