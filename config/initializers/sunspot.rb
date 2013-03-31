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
      #     Sunspot.search Post do
      #        keywords 'great pizza'
      #       adjust_solr_params do |params|
      #         params[:"spellcheck"] = true
      #         params[:"spellcheck.collate"] = true
      #       end
      #     end
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
      #   [{"startOffset"=>0, "endOffset"=>6, "origFreq"=>0, "suggestion"=>[{"word"=>"flower", "freq"=>30}, {"word"=>"flowers", "freq"=>8}], "numFound"=>2}, {"startOffset"=>7, "endOffset"=>14, "origFreq"=>0, "suggestion"=>[{"word"=>"originals", "freq"=>2}], "numFound"=>1}]
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

# we can send this class to DJ to automatically Sunspot.commit indexing at a given interval (default = 1.hour). It reschedules itself.
#
# @example initialize with 30 minute interval:
#
#   @comitter = SunspotCommiter.new 30.minutes
#
# @example send it to DJ:
#
#   @comitter.delay.perform 
# 
# It will run Sunspot.commit immediately, and after it ran successfully, it reschedules itself to run again next time at the given interval.
#
# @example to stop, the DJ entry has to be deleted from the db:
#
#   Delayed::Job.where(:handler => /SunspotCommiter/).last.delete
#
SunspotCommiter = Struct.new(:interval) do
  def perform
    Sunspot.commit
    next_time = lambda {Time.now + (interval || 1.hour)}
    Delayed::Job.enqueue self, 0, next_time.call.utc
  end  
end

module EllisonExceptionHandler
  def self.handle(exception)
    UserMailer.exception_message(exception).deliver
  end
end

Sunspot::Rails::Failover.exception_handler = EllisonExceptionHandler
Sunspot::Rails::Failover.setup


module Sunspot
  module Mongoid
    class DataAccessor < Sunspot::Adapters::DataAccessor
      private

      def criteria(id)
        @clazz.find(id)
      end
    end
  end
end
