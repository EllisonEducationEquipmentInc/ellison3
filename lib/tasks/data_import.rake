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
  end

end