class DynamicCache
  
  def initialize(app)  
    @app = app  
  end
  
  def call(env)
    if should_cache?(env)
      
      domain_to_system(env['HTTP_HOST'])
      set_current_system env["rack.session"]["system"] # TODO: disable in production 
      
      I18n.locale = env["rack.session"]["locale"] if env["rack.session"]["locale"] && allowed_locales.include?(env["rack.session"]["locale"].to_s)
  		set_default_locale unless allowed_locales.include?(I18n.locale.to_s)
  		
  		Rails.cache.fetch(["cached_page_#{env["PATH_INFO"]}", env['QUERY_STRING'], current_system, current_locale], :expires_in => 1.minutes) do
  		  status, headers, response = @app.call(env)
  		  [status, headers, response.body]
  		end  		
    else
      @app.call(env)
    end
  rescue Exception => e
    [500, {"Content-Type" => 'text/plain; charset=utf-8'}, [e.to_s]]
  end
  
  def should_cache?(env)
    (env["PATH_INFO"] =~ /^\/$/ || env["PATH_INFO"] =~ /^\/index\/(limited_|quick_)?search/) && env["rack.session"].present? && env["rack.session"]["system"].present? && env["rack.session"]["system"] != 'er' && env["rack.session"]["locale"].present? #&& env['QUERY_STRING'].blank?
  end
  
end