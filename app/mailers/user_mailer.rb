class UserMailer < ActionMailer::Base
  
  def order_confirmation(order)
    @order = order
    mail(:to => order.user.email, :subject => "#{get_domain.capitalize} Order confirmation.")
  end
  
  def quote_confirmation(quote)
    @quote = quote
    mail(:to => quote.user.email, :subject => "#{get_domain.capitalize} #{quote_name} confirmation.")
  end
end
