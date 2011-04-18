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
		match "myaccount/quote/:id", :to => "users#quote", :as => :myquote
		match "list/:id", :to => "users#list", :as => :list
		get "billing", :to => "users#billing"
		get "shipping", :to => "users#shipping"
		get "mylists", :to => "users#mylists"
		get "orders", :to => "users#orders"
		get "quotes", :to => "users#quotes"
		get "materials", :to => "users#materials"
		get "edit_address", :to => "users#edit_address"
		get "checkout_requested", :to => "users#checkout_requested"
		get "quote_requested", :to => "users#quote_requested"
		get "signin_signup", :to => "users#signin_signup"
		post "update_address", :to => "users#update_address"
		post "update_list", :to => "users#update_list"
		post "create_list", :to => "users#create_list"
		delete "delete_list", :to => "users#delete_list"
		post "user_as", :to => "sessions#user_as"
		get "add_to_list", :to => "users#add_to_list"
		get "users/save_for_later", :to => "users#save_for_later"
		get "list_set_to_default", :to => "users#list_set_to_default"
		delete "remove_from_list", :to => "users#remove_from_list"
		post "move_to_list", :to => "users#move_to_list"
		post "users/email_list", :to => "users#email_list"
		get "users/get_lists", :to => "users#get_lists"
		get "retailer_application", :to => "users#retailer_application", :as => :retailer_application
		post "users/create_retailer_application", :to => "users#create_retailer_application"
		get 'users/view_retailer_application', :to => "users#view_retailer_application"
		get 'users/machines_i_own', :to => "users#machines_i_own"
		get 'users/subscriptions', :to => "users#subscriptions"
		post 'users/order_material', :to => "users#order_material"
		get 'eclipsware', :to => "users#eclipsware"
		post 'users/show_fw_files', :to => "users#show_fw_files"
		get 'users/download_firmware', :to => "users#download_firmware"
		get 'users/messages', :to => "users#messages"
		post 'users/change_quote_name', :to => "users#change_quote_name"
  end

  match 'admin' => 'admin#index'

  match 'shop/:id' => 'index#shop', :as => :shop
  match 'lp/:id' => 'index#tag_group'
	match 'products' => 'index#products'
	match 'stores' => 'index#stores', :as => :stores
	match 'campaigns' => 'index#campaigns'
	match 'events' => 'index#events'
	match 'event/:id' => 'index#event', :as => :event
	match 'catalog' => 'index#catalog', :as => :catalog
	match 'outlet' => 'index#shop', :defaults => { :id => 'outlet' }, :as => :outlet
	
	# redirects from rails 2 url's
	match 'product/:old_id' => 'index#old_product', :old_id => /\d{1,5}/
	match 'idea/:old_id' => 'index#old_idea', :old_id => /\d{1,4}/
	match 'catalog/:tag_type/:name' => 'index#old_catalog'
	
	match 'product/:id' => 'index#product', :id => /[0-9a-f]{24}/
	match 'product/:item_num(/:name)' => 'index#product', :as => :product
	match 'idea/:id' => 'index#idea', :id => /[0-9a-f]{24}/
	match 'idea/:idea_num(/:name)' => 'index#idea', :as => :idea
		
	#match 'lesson/:id' => 'index#idea', :as => :idea, :constraints => Proc.new {|obj| obj.is_ee?}
	#match 'project/:id' => 'index#idea', :as => :idea, :constraints => Proc.new {|obj| !obj.is_ee?}
	match 'contact' => 'index#contact', :as => :contact
	match 'reply_to_feedback/:id' => 'index#reply_to_feedback', :as => :reply_to_feedback
	match 'videos' => 'index#videos', :as => :videos
	
	match 'forget_credit_card' => 'carts#forget_credit_card', :as => :forget_credit_card
	match 'cart' => 'carts#index', :as => :cart
	match 'checkout' => 'carts#checkout', :as => :checkout
	match 'quote' => 'carts#quote', :as => :quote
	match 'pre_order' => 'carts#quote', :as => :pre_order
	match 'activate_coupon' => 'carts#activate_coupon', :as => :activate_coupon
	match 'remove_coupon' => 'carts#remove_coupon', :as => :remove_coupon
	match 'remove_order_reference' => 'carts#remove_order_reference', :as => :remove_order_reference
	match 'instructions' => 'index#instructions'
	
	match '/calendar(/:year(/:month))' => 'index#calendar', :as => :calendar, :constraints => {:year => /\d{4}/, :month => /\d{1,2}/}
	
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
			    get :new_campaign, :edit_campaign, :new_image, :new_tab, :products_autocomplete, :reorder_tabs, :show_tabs, :product_helper, :product_helper_by_tag, :remove_tag, :add_tag, :remove_idea, :add_idea
					post :create_campaign, :update_campaign, :upload_image, :create_tab, :update_tab, :clone_existing_tab, :edit_outlet_price
					delete :delete_campaign, :delete_image, :delete_tab, :remove_all_products
					put :update_campaign, :update_tab
			  end
			end
			resources :ideas do
				collection do
			    get :new_image, :new_tab, :ideas_autocomplete, :reorder_tabs, :show_tabs, :idea_helper, :idea_helper_by_tag, :remove_product, :add_product, :remove_tag, :add_tag
					post :upload_image, :create_tab, :update_tab, :clone_existing_tab
					delete :delete_image, :delete_tab
					put :update_tab
			  end
			end
			resources :us_shipping_rates, :as => :fedex_rates
			resources :shipping_rates
			resources :messages
			resources :users do
			  collection do
			    get :view_retailer_application, :edit_token
			    put :update_token
			  end
			end
			resources :countries
			resources :orders do
			  collection do
			    post :update_internal_comment, :change_order_status, :change_shipping, :make_payment, :update_estimated_ship_date
			    get :recalculate_tax, :recreate, :refund_cc
			  end
			end
			resources :material_orders do
			  collection do
			    post :change_order_status, :export_to_csv
			  end
			end
			resources :quotes do
			  collection do
			    post :update_internal_comment, :change_quote_name, :change_shipping
			    get :update_active_status, :recreate, :pre_orders_report, :login_as_and_goto_quote, :recalculate_tax
			  end
			end
			resources :coupons, :stores, :events, :materials, :search_phrases
			resources :static_pages
			resources :shared_contents do
			  collection do
			    get :shared_contents_autocomplete, :reorder_visual_assets
			  end
			end
			resources :landing_pages do
			  collection do
			    get :reorder_visual_assets
			  end
			end
			resources :tags do
				collection do
			    get :tags_autocomplete, :reorder_visual_assets, :remove_product, :add_product, :remove_idea, :add_idea
			  end
			end
			resources :compatibilities do
				collection do
			    get :tags_autocomplete
			  end
			end
			resources :profiles, :as => 'admins'
			resources :feedbacks do
			  collection do
			    post :update_attribute
			  end
			end
      
      resources :navigations
      
      match 'virtual_terminal(/:action(/:id(.:format)))' => "virtual_terminal"
      match 'firmwares(/:action(.:format))' => "firmwares"
      match 'discount_categories(/:action(.:format))' => "discount_categories"
      match 'reports(/:action(.:format))' => "reports"
    end

      
  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "index#home"

	#match "/grid/*path" => Gridfs #"gridfs#serve"
  # match "/solr_terms/:term" => SolrTerms
	
  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  match ':controller(/:action(/:id(.:format)))'
  match ':controller(/:action(.:format))'
  
  
	# static and 404 pages middleware route
	match "*path.html" => "static_pages#serve"

  match ':id' => 'index#static_page'

end
