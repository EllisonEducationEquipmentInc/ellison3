module NewRelicWrapper
	def new_relic_wrapper(name = "rake", &block)
	  include NewRelic::Agent::Instrumentation::ControllerInstrumentation
	  NewRelic::Agent.manual_start
	  sleep(2)
	  #NewRelic::Agent.agent.started?
	  perform_action_with_newrelic_trace(:name => name, :category => :task) do
	    yield
	  end
	  sleep(2)
	  NewRelic::Agent.shutdown
	end
end