namespace :data_import do

  desc "import tradeshow orders from /data/shared/tradeshow_orders/tradeshow_orders.xml"
  task :tradeshow_orders => :environment do
    set_current_system "erus"
    vat = SystemSetting.value_at("vat").to_f
    File.open("/data/shared/tradeshow_orders/tradeshow_orders.xml", "r") do |file|
      @xml = file.read
    end
    @doc = Nokogiri::XML @xml
    @doc.xpath("//orders//order").each do |order|
      email = order.children.at_css("email").text.present? ? order.children.at_css("email").text : "tradeshow_#{order.children.at_css('id').text}@ellison.com"
      @user = User.where(:systems_enabled.in => ["erus"], :erp => order.children.at_css("customer_number").text).first || User.where(:systems_enabled.in => ["erus"], :email => email).first
      if @user
        p "User found..."
      else
        @user = User.new :email => email, :password => Digest::SHA1.hexdigest("temp_password_#{rand(10000)}#{Time.now.to_f.to_s}")[0,20], :company => order.children.at_css('business').text
        if @user.save
          p "User NOT found. Creating user #{email}"
        else
          p "!!! unable to create user! #{@user.errors}"
        end
      end
      @quote = Quote.new :created_at => order.children.at_css('created_at').text, :updated_at => order.children.at_css('updated_at').text, :quote_number => order.children.at_css('id').text, :locale => current_locale, :subtotal_amount => order.children.at_css('sub_total').text, 
        :shipping_amount => 0.0, :handling_amount => 0.0, :tax_amount => order.children.at_css('sales_tax').text, :vat_exempt => true, :vat_percentage => vat, :tax_exempt => Boolean.set(order.children.at_css('tax_exempt').text), :tax_exempt_number => order.children.at_css('tax_exempt_number').text, 
        :to_review => true, :shipping_priority => "Normal", :shipping_service => "unknown", :comments => order.children.at_css('notes').text, :internal_comments => ''
      
      @quote.build_address :first_name => order.children.at_css('first_name').text, :last_name => order.children.at_css('last_name').text, :company => order.children.at_css('business').text, :address1 => order.children.at_css('address').text, :city => order.children.at_css('city').text, :state => order.children.at_css('state').text, :zip_code => order.children.at_css('zip_code').text, :country => order.children.at_css('country').text, :phone => order.children.at_css('phone').text, :email => @user.email
      @quote.user = @user
      
      order.children.xpath("order_item").each do |order_item|
        @product = Product.where(:item_num => order_item.at_css("product item_num").text).first
        unless @product
          msg = "!!! product #{order_item.at_css('product item_num').text} was NOT found in the system. Skipping line item... Order #: #{order.children.at_css('id').text}\n"
          p msg
          @quote.internal_comments << msg
          next
        end
        sale_price = order_item.at_css("price").text.to_i
        @quote.order_items << OrderItem.new(:name => @product.name, :item_num => @product.item_num, :sale_price => sale_price, :quoted_price => @product.msrp_or_wholesale_price, :quantity => order_item.at_css("quantity").text,
				    :locale => current_currency, :product => @product, :tax_exempt => @quote.tax_exempt, :discount => (@product.msrp_or_wholesale_price - sale_price rescue 0.0), :vat => 0.0)
        p order_item.at_css("product_id").text
      end
      
      if @quote.save
        "Quote #{order.children.at_css('id').text} has been imported..."
      else
        p "!!! unable to save quote #{order.children.at_css('id').text} : #{@quote.errors}"
      end      
    end
    `rm -f /data/shared/tradeshow_orders/tradeshow_orders.xml`
  end

  desc "update msrp from /data/shared/data_files/msrp_update.csv"
  task :update_msrp => :environment do
    CSV.foreach("/data/shared/data_files/msrp_update.csv", :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first 
      next unless @product
      LOCALES_2_CURRENCIES.values.each do |currency|
        @product.send "msrp_#{currency}=", row["msrp_#{currency}"] if row["msrp_#{currency}"].present?
        @product.send "wholesale_price_#{currency}=", row["wholesale_price_#{currency}"] if row["wholesale_price_#{currency}"].present?
      end
      begin
        p @product.save(:validate => false)        
      rescue Exception => e
        p "!!! ERROR: product #{@product.item_num} was NOT saved. Make sure you manually update this product. #{e}"
      end
    end
  end
  
  desc "expire EEUK products"
  task :expire_products => :environment do
    set_current_system "eeuk"
    CSV.foreach("/data/shared/data_files/products_to_expire.csv", :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @product = Product.where(:item_num => row['item_num']).first
      next unless @product
      @product.update_attributes :end_date_eeuk => 2.day.ago
    end
  end
  
  desc "assiciate products with tag"
  task :products_to_tag => :environment do
    CSV.foreach("/data/shared/data_files/tag_product_association.csv", :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @tag = Tag.find(row['tag_id']) unless @tag.present? && @tag.id.to_s == row['tag_id']
      @product = Product.where(:item_num => row['item_num']).first
      next unless @product
      p "associating #{@product.item_num} with #{@tag.name}"
      @product.add_to_collection "tags", @tag
      @product.index_by_tag(@tag) if @tag.active 
    end
    Sunspot.delay.commit
  end
  
  desc "assiciate ideas with tag"
  task :ideas_to_tag => :environment do
    CSV.foreach("/data/shared/data_files/tag_idea_association.csv", :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @tag = Tag.find(row['tag_id']) unless @tag.present? && @tag.id.to_s == row['tag_id']
      @idea = Idea.where(:idea_num => row['idea_num']).first
      next unless @idea
      p "associating #{@idea.idea_num} with #{@tag.name}"
      @idea.add_to_collection "tags", @tag
      @idea.index_by_tag(@tag) if @tag.active
    end
    Sunspot.delay.commit
  end
  
  desc "import lyris subscriptions"
  task :lyris_subscriptions => :environment do
    set_current_system ENV['system'] || "szus"
    get_list_and_segments
    CSV.foreach("/data/shared/data_files/lyris.csv", :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @subscription = Subscription.first(:conditions => {:email => row['email'].downcase, :list => subscription_list}) || Subscription.new 
      @subscription.email = row['email'].downcase
      @subscription.confirmed = true
      @subscription.list = subscription_list
      @subscription.list_name = @list[1]
      @segments.keys.map(&:to_s).each do |segment|
        @subscription.segments << segment if row[segment] == "1"
      end
      @subscription.segments.uniq!
      @subscription.save
      p "===== #{@subscription.valid?} #{@subscription.email} #{@subscription.list} ===="
      Lyris.delay.new :create_single_member, :email_address => @subscription.email, :list_name => @subscription.list, :full_name => @subscription.name
      Lyris.delay.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'normal'
      Lyris.delay.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @subscription.segments.map {|e| {:name => e.to_sym, :value => 1}} << {:name => :subscription_id, :value => @subscription.id.to_s}
    end
  end
end
