class UserMailer < ActionMailer::Base
  
  def order_confirmation(order)
    @order = order
    to = [order.address.try(:email), order.payment.try(:email), order.user.email].compact.uniq
    mail(:to => to, :subject => "#{get_domain.capitalize} Order Confirmation", :cc => cc_sales_rep? && order.user.try(:admin) ? order.user.admin.email : nil )
  end
  
  def quote_confirmation(quote)
    @quote = quote
    to = [quote.address.try(:email), quote.user.email].compact.uniq
    mail(:to => to, :subject => "#{get_domain.capitalize} #{quote_name} Confirmation", :cc => cc_sales_rep? && quote.user.try(:admin) ? quote.user.admin.email : nil)
  end
  
  def shipping_confirmation(order)
    @order = order
    set_current_system order.system
    to = [order.address.try(:email), order.payment.try(:email), order.user.email].compact.uniq
    mail(:to => to, :subject => "#{get_domain.capitalize} Shipping Confirmation", :cc => cc_sales_rep? && order.user.try(:admin) ? order.user.admin.email : nil )
  end
  
  def email_list(user, name, recipients, wishlist, note)
		@from = user.email
		@list = wishlist
		@name = name
		@note = note
		mail(:from => user.email, :to => recipients, :subject => "#{name} wants to share their #{get_domain.capitalize} List with you")
	end
	
	def feedback_confirmation(feedback)
	  set_current_system feedback.system
	  @feedback = feedback
	  mail(:to => feedback.email, :subject => "[#{get_domain.capitalize}] - Thank you for your Inquiry. #{feedback.subject} - #{feedback.number}")
	end
	
	def feedback_reply(feedback)
	  original_system = current_system
	  set_current_system feedback.system
	  @feedback = feedback
	  mail(:to => feedback.email, :subject => "RE: [#{get_domain.capitalize}] #{feedback.subject} - #{feedback.number}")
	  set_current_system original_system
	  render :layout => 'feedback_reply'
	end
	
	def subscription_confirmation(subscription)
	  @subscription = subscription
	  mail(:to => subscription.email, :subject => "#{get_domain.capitalize} #{subscription.list_name} Subscription Confirmation")
	end
	
	def exception_message(exception)
	  @exception = exception
	  mail(:to => ["mronai@ellison.com", "mbarla@ellison.com"], :subject => "An Exception Occured")	  
	end
end
