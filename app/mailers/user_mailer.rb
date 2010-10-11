class UserMailer < ActionMailer::Base
  
  def order_confirmation(order)
    @order = order
    mail(:to => order.user.email, :subject => "#{get_domain.capitalize} Order confirmation.")
  end
end
