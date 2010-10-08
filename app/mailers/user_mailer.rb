class UserMailer < ActionMailer::Base
  default :from => "consumersupport@#{get_domain}"
  
  def order_confirmation(order)
    @order = order
    mail(:to => order.user.email, :subject => "#{get_domain.capitalize} Order confirmation.")
  end
end
