class UserMailer < ActionMailer::Base
  
  def order_confirmation(order)
    @order = order
    to = [order.address.try(:email), order.payment.try(:email), order.user.email].compact.uniq
    mail(:to => to, :subject => "#{get_domain.capitalize} Order Confirmation", :cc => order.user.try(:admin) ? order.user.admin.email : nil )
  end
  
  def quote_confirmation(quote)
    @quote = quote
    to = [quote.address.try(:email), quote.user.email].compact.uniq
    mail(:to => to, :subject => "#{get_domain.capitalize} #{quote_name} Confirmation", :cc => quote.user.try(:admin) ? quote.user.admin.email : nil)
  end
  
  def email_list(user, name, recipients, wishlist, note)
		@from = user.email
		@list = wishlist
		@name = name
		@note = note
		mail(:from => user.email, :to => recipients, :subject => "#{name} wants to share their #{get_domain.capitalize} List with you")
	end
	
	def feedback_reply(feedback)
	  @feedback = feedback
	  mail(:to => feedback.email, :subject => "RE: [#{get_domain.capitalize}] #{feedback.subject} - #{feedback.id}")
	end
end
