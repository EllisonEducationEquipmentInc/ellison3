class StaticPagesController < ActionController::Metal
  include EllisonSystem
  include ActionController::Rendering

  append_view_path "#{Rails.root}/app/views"

  def serve
    begin
      render params[:path]
    rescue
      Rails.logger.info "Wewe #{request.fullpath}"
      domain_to_system(env['HTTP_HOST'])
      set_current_system(params[:system]) if params[:system] && Rails.env == 'development'
      render "#{Rails.root}/public/404_#{current_system}.html", :status => 404 unless request.fullpath =~ /\.[a-zA-Z0-9]{2,4}(\?\d{10})?$/ && request.fullpath !~ /\.html?\Z/
    end
  end

end
