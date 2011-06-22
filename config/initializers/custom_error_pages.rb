module ActionDispatch
  # This middleware rescues any exception returned by the application and renders
  # nice exception pages if it's being rescued locally.
  
  class ShowExceptions
    
    private
      
      def rescue_action_in_public(exception)
        status = status_code(exception)
        locale_path = "#{public_path}/#{status}.#{I18n.locale}.html" if I18n.locale
        
        if self.respond_to?(:current_system) && current_system
          path = "#{public_path}/#{status}_#{current_system}.html"
        else
          path = "#{public_path}/#{status}.html"
        end

        if locale_path && File.exist?(locale_path)
          render(status, File.read(locale_path))
        elsif File.exist?(path)
          render(status, File.read(path))
        else
          render(status, '')
        end
      end
  end
end