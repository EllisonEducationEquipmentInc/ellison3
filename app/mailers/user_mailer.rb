class UserMailer < ActionMailer::Base
  
  def order_confirmation(order)
    @order = order
    mail(:to => order.user.email, :subject => "#{get_domain.capitalize} Order Confirmation")
  end
  
  def quote_confirmation(quote)
    @quote = quote
    mail(:to => quote.user.email, :subject => "#{get_domain.capitalize} #{quote_name} Confirmation")
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
