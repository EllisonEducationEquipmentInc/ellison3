Ellison3::Application.routes.draw do |map|
	
  # The priority is based upon order of creation:
  # first created -> highest priority.

  devise_for :users, :controllers => { :registrations => "users", :sessions => "sessions" }
	devise_for :admins, :controllers => {:registrations => "admin/registrations", :sessions => "admin/sessions" }

	# Sets the devise scope to be used in the controller. 
	as :user do
    # get "myaccount", :to => "users#myaccount"
		match "myaccount(/:tab)", :to => "users#myaccount", :as => :myaccount
		match "myaccount/order/:id", :to => "users#order", :as => :order
		get "billing", :to => "users#billing"
		get "shipping", :to => "users#shipping"
		get "mylists", :to => "users#mylists"
		get "orders", :to => "users#orders"
		get "quotes", :to => "users#quotes"
		get "materials", :to => "users#materials"
		get "edit_address", :to => "users#edit_address"
		get "checkout_requested", :to => "users#checkout_requested"
		get "signin_signup", :to => "users#signin_signup"
		post "update_address", :to => "users#update_address"
		post "user_as", :to => "sessions#user_as"
  end

  match 'admin' => 'admin#index'

  match 'shop/:id' => 'index#shop', :as => :shop
	match 'products' => 'index#products'
	match 'catalog' => 'index#catalog'
	match 'product/:id' => 'index#product', :as => :product
	
	match 'forget_credit_card' => 'carts#forget_credit_card', :as => :forget_credit_card
	match 'cart' => 'carts#index', :as => :cart
	match 'checkout' => 'carts#checkout', :as => :checkout
	match 'activate_coupon' => 'carts#activate_coupon', :as => :activate_coupon
	match 'remove_coupon' => 'carts#remove_coupon', :as => :remove_coupon
	
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
			    get :new_campaign, :edit_campaign, :new_image, :new_tab, :products_autocomplete, :reorder_tabs, :show_tabs, :product_helper
					post :create_campaign, :update_campaign, :upload_image, :create_tab, :update_tab, :clone_existing_tab
					delete :delete_campaign, :delete_image, :delete_tab
					put :update_campaign, :update_tab
			  end
			end
			resources :users
			resources :orders do
			  collection do
			    post :update_internal_comment
			  end
			end
			resources :coupons
			resources :landing_pages
			resources :tags do
				collection do
			    get :tags_autocomplete
			  end
			end
			resources :profiles, :as => 'admins'			
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
