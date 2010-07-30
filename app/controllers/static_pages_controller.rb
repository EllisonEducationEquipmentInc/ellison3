class StaticPagesController < ActionController::Metal
	include EllisonSystem
	include ActionController::Rendering  

	append_view_path "#{Rails.root}/app/views"

  def serve
		begin
  		render params[:path]
		rescue
			# TODO: include module that gets system from domain
			set_current_system(params[:system]) if params[:system]
			render "#{Rails.root}/public/404_#{current_system}.html", :status => 404 unless request.fullpath =~ /\.[a-zA-Z0-9]{2,4}(\?\d{10})?$/
		end
  end

end