class UserMailer < ActionMailer::Base
  
  def order_confirmation(order)
    @order = order
    mail(:to => order.user.email, :subject => "#{get_domain.capitalize} Order confirmation.")
  end
  
  def quote_confirmation(quote)
    @quote = quote
    mail(:to => quote.user.email, :subject => "#{get_domain.capitalize} #{quote_name} confirmation.")
  end
  
  def email_list(user, name, recipients, wishlist, note)
		@from = user.email
		@list = wishlist
		@name = name
		@note = note
		mail(:from => user.email, :to => recipients, :subject => "#{name} wants to share their #{get_domain.capitalize} List with you")
	end
end
