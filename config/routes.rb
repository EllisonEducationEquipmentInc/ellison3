Ellison3::Application.routes.draw do
	
  # The priority is based upon order of creation:
  # first created -> highest priority.

  devise_for :users, :controllers => { :registrations => "users", :sessions => "sessions" }, :format => false
	devise_for :admins, :controllers => {:registrations => "admin/registrations", :sessions => "admin/sessions" }

	# Sets the devise scope to be used in the controller. 
	as :user do
    # get "myaccount", :to => "users#myaccount"
		match "myaccount(/:tab)", :to => "users#myaccount", :as => :myaccount, :format => false
		match "myaccount/order/:id", :to => "users#order", :as => :order, :format => false
		match "myaccount/quote/:id", :to => "users#quote", :as => :myquote, :format => false
		match "list/:id", :to => "users#list", :as => :list, :format => false
		get "billing", :to => "users#billing", :format => false
		get "shipping", :to => "users#shipping", :format => false
		get "mylists", :to => "users#mylists", :format => false
		get "orders", :to => "users#orders", :format => false
		get "quotes", :to => "users#quotes", :format => false
		get "materials", :to => "users#materials", :format => false
		get "edit_address", :to => "users#edit_address"
		get "checkout_requested", :to => "users#checkout_requested"
		get "quote_requested", :to => "users#quote_requested", :format => false
		get "signin_signup", :to => "users#signin_signup", :format => false
		post "update_address", :to => "users#update_address"
		post "update_list", :to => "users#update_list", :format => false
		post "create_list", :to => "users#create_list", :format => false
		delete "delete_list", :to => "users#delete_list", :format => false
		post "user_as", :to => "sessions#user_as", :format => false
		get "add_to_list", :to => "users#add_to_list", :format => false
		get "users/save_for_later", :to => "users#save_for_later", :format => false
		get "list_set_to_default", :to => "users#list_set_to_default", :format => false
		delete "remove_from_list", :to => "users#remove_from_list", :format => false
		post "move_to_list", :to => "users#move_to_list", :format => false
		post "users/email_list", :to => "users#email_list", :format => false
		get "users/get_lists", :to => "users#get_lists", :format => false
		get "retailer_application", :to => "users#retailer_application", :as => :retailer_application, :format => false
		post "users/create_retailer_application", :to => "users#create_retailer_application", :format => false
		get 'users/view_retailer_application', :to => "users#view_retailer_application", :format => false
		get 'users/machines_i_own', :to => "users#machines_i_own", :format => false
		get 'users/subscriptions', :to => "users#subscriptions", :format => false
		post 'users/order_material', :to => "users#order_material", :format => false
		get 'eclipsware', :to => "users#eclipsware", :format => false
		post 'users/show_fw_files', :to => "users#show_fw_files", :format => false
		get 'users/download_firmware', :to => "users#download_firmware", :format => false
		get 'users/messages', :to => "users#messages", :format => false
		post 'users/change_quote_name', :to => "users#change_quote_name", :format => false
		post 'users/resend_subscription_confirmation', :to => "users#resend_subscription_confirmation", :format => false
		get 'login', :to => "sessions#new", :format => false, :as => :login
		get 'signup', :to => "users#new", :format => false, :as => :signup
  end

  match 'shop/:id' => 'index#shop', :as => :shop, :format => false
  match 'lp/:id' => 'index#tag_group', :as => :tag_group, :format => false
	match 'products' => 'index#products', :format => false
	match 'home' => 'index#home', :format => false
	match 'latinamerica' => 'index#stores', :format => false
	
	match 'stores' => 'index#stores', :as => :stores, :format => false
	match 'campaigns' => 'index#campaigns', :format => false
	match 'events' => 'index#events', :format => false
	match 'blogs' => 'index#blog_uk', :format => false, :as => :blog_uk
	match 'event/:id' => 'index#event', :as => :event, :format => false
	match 'catalog' => 'index#catalog', :as => :catalog, :format => false
	match 'outlet' => 'index#shop', :defaults => { :id => 'clearance' }, :as => :clearance, :format => false
	
	# redirects from rails 2 url's
	match 'product/:old_id' => 'index#old_product', :old_id => /\d{1,5}/, :format => false
	match 'idea/:old_id' => 'index#old_idea', :old_id => /\d{1,4}/, :format => false
	match 'catalog/:tag_type/:name' => 'index#old_catalog', :format => false
	
	match 'product/:id' => 'index#product', :id => /[0-9a-f]{24}/, :format => false
	match 'product/:item_num(/:name)' => 'index#product', :as => :product, :format => false
	match 'idea/:id' => 'index#idea', :id => /[0-9a-f]{24}/, :format => false
	match 'idea/:idea_num(/:name)' => 'index#idea', :as => :idea, :format => false
		
	#match 'lesson/:id' => 'index#idea', :as => :idea, :constraints => Proc.new {|obj| obj.is_ee?}
	#match 'project/:id' => 'index#idea', :as => :idea, :constraints => Proc.new {|obj| !obj.is_ee?}
	match 'contact' => 'index#contact', :as => :contact, :format => false
	match 'reply_to_feedback/:id' => 'index#reply_to_feedback', :as => :reply_to_feedback, :format => false
	match 'videos' => 'index#videos', :as => :videos, :format => false
	
	match 'forget_credit_card' => 'carts#forget_credit_card', :as => :forget_credit_card, :format => false
	match 'cart' => 'carts#index', :as => :cart, :format => false
	match 'checkout' => 'carts#checkout', :as => :checkout, :format => false
	match 'quote' => 'carts#quote', :as => :quote, :format => false
	match 'pre_order' => 'carts#quote', :as => :pre_order, :format => false
	match 'activate_coupon' => 'carts#activate_coupon', :as => :activate_coupon, :format => false
	match 'add_to_cart_by_item_num' => "carts#add_to_cart_by_item_num", :as => :add_to_cart_by_item_num, :format => false
	match 'remove_coupon' => 'carts#remove_coupon', :as => :remove_coupon, :format => false
	match 'remove_order_reference' => 'carts#remove_order_reference', :as => :remove_order_reference, :format => false
	match 'instructions' => 'index#instructions', :format => false
	
	match '/calendar(/:year(/:month))' => 'index#calendar', :as => :calendar, :constraints => {:year => /\d{4}/, :month => /\d{1,2}/}, :format => false
	
	match '/upload/fast_upload' => 'carts#fast_upload', :as => :fast_upload, :format => false
 
   
	
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
			    post :update_internal_comment, :change_quote_name, :change_shipping, :change_quote_date
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
			resources :subscriptions do
			  collection do
			    get :upload
          post :fast_upload
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
      
      resources :navigations, :system_settings, :bloggers
      resources :system_settings do
        collection do
			    post :save_vat, :save_free_shipping_message
			  end
      end
      
      match 'virtual_terminal(/:action(/:id(.:format)))' => "virtual_terminal"
      match 'firmwares(/:action(.:format))' => "firmwares"
      match 'discount_categories(/:action(.:format))' => "discount_categories"
      match 'reports(/:action(.:format))' => "reports"
      match 'solr(/:action(/:id(.:format)))' => "solr"
    end

      
  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "index#home", :format => false
  
  #match "/grid/*path" => Gridfs #"gridfs#serve"
  # match "/solr_terms/:term" => SolrTerms
	
  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  #match ':controller(/:action(/:id(.:format)))'
  #match ':controller(/:action(.:format))'
  
  match 'admin' => 'admin#index', :format => false, as: :admin

  match ':controller(/:action(/:id))', :format => false
  match ':controller(/:action(.:format))'

  match "carts/quote_2_order/:id(.:format)" => "carts#quote_2_order"
  match 'index/:action' => 'index', :format => false
  match 'carts/:action' => 'carts', :format => false
  
	# static and 404 pages middleware route
	match "*path.html" => "static_pages#serve", :format => false

    match ':id' => 'index#static_page', :format => false
  end
