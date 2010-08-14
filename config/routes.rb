Ellison3::Application.routes.draw do |map|
  # The priority is based upon order of creation:
  # first created -> highest priority.

	match 'products' => 'index#products'
	match 'product/:id' => 'index#product', :as => :product
	
  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get :short
  #       post :toggle
  #     end
  #
  #     collection do
  #       get :sold
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get :recent, :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
    namespace :admin do
      # Directs /admin/products/* to Admin::ProductsController
      # (app/controllers/admin/products_controller.rb)
      resources :products do
				collection do
			    get :new_campaign
					post :create_campaign
					post :update_campaign
					delete :delete_campaign
					get :edit_campaign
					put :update_campaign
					post :upload_image
					get :new_image
					delete :delete_image
					get :new_tab
					post :create_tab
					post :update_tab
					put :update_tab
					delete :delete_tab
					get :products_autocomplete
					get :reorder_tabs
			  end
			end
    end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "index#home"

	match "/images/uploads/*path" => "gridfs#serve"
	
  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  match ':controller(/:action(/:id(.:format)))'

	# static and 404 pages middleware route
	match "*path" => "static_pages#serve"
end
