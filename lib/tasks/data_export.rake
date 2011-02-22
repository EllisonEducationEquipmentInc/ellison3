namespace :data_export do
  
  # example:
  #    rake data_export:google_atom system=eeus
  desc "exports product to google atom feed"
	task :google_atom => :environment do
	  set_current_system ENV['system'] || "szus"
		include ActionView::Helpers::AtomFeedHelper
		new_relic_wrapper "google_atom" do
    
  		PATH = Rails.env == 'development' ? Rails.root : "/data/shared/cron"
  		File.open("#{PATH}/#{current_system}_product_feed.xml", "w") do |file|
  			xml = Builder::XmlMarkup.new(:target=>file, :indent=>2)
  			atom_feed({:xml => xml, :id => "tag:#{get_domain},2005:/admin/products/google_feed", :root_url => "http://#{get_domain}/", :url => "http://#{get_domain}/admin/products/google_feed.atom",
  				 						'xmlns' => 'http://www.w3.org/2005/Atom', 'xmlns:g' => 'http://base.google.com/ns/1.0'}) do |feed|
  			  feed.title("#{current_system}_product_feed.xml")
  			  feed.updated(Time.zone.now)
  				Product.listable.in_batches(100) do |group|
  				  group.each do |product|
							print "."
					    feed.entry(product, :id => product.id, :url => "http://www.#{get_domain}/product/#{product.item_num}/#{product.name.parameterize}") do |entry|
					      entry.title(product.name)
					      entry.description(product.description)
								entry.tag!("g:image_link", "http://www.#{get_domain}#{product.medium_image}")
								entry.tag!("g:price", product.price)
								entry.tag!("g:condition", "new")
								entry.tag!("g:product_type", "Arts & Entertainment > Crafts & Hobbies > Scrapbooking")
								entry.tag!("g:brand", is_sizzix? ? "Sizzix" : "Ellison") 
								#entry.tag!("g:id", product.item_num)
								entry.tag!("g:upc", product.upc) unless product.upc.blank?
								entry.tag!("g:mpn", product.item_num)
					    end
  				  end
  				end
  			end
  		end
  		p ''
  		p "exporting #{current_system} products to #{current_system}_product_feed.xml has completed"
  	end
	end
	
	desc "reindex all products"
	task :reindex_products => :environment do
	  new_relic_wrapper "reindex_products" do
	    Product.all.in_batches(50) do |batch|
        batch.each do |product|
          product.delay.index! rescue next
          p "#{product.item_num}"
        end
      end
	  end
	end
	
	desc "reindex all ideas"
	task :reindex_ideas => :environment do
	  new_relic_wrapper "reindex_ideas" do
	    Idea.all.in_batches(50) do |batch|
        batch.each do |idea|
          idea.delay.index! rescue next
          p "#{idea.idea_num}"
        end
      end
	  end
	end
	
end