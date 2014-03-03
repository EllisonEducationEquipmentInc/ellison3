class EcalsController < ApplicationController

  def new
    @title = "eCAL Lite Activation"
    @ecallite = EcalActivation.new
  end

  def create
    @title = "eCAL Lite Activation"
    @ecallite = EcalActivation.new params[:ecal_activation]
    @ecallite.activation_code = "#{params[:activation_code_1]}-#{params[:activation_code_2]}-#{params[:activation_code_3]}-#{params[:activation_code_4]}-#{params[:activation_code_5]}"
    if @ecallite.valid?
      response = Curl::Easy.perform("https://www.craftedge.com/ecal_lite/redeem.php?code=#{@ecallite.activation_code}&fname=#{CGI::escape @ecallite.first_name}&lname=#{CGI::escape @ecallite.last_name}&email=#{CGI::escape @ecallite.email}")
      code = response.body_str.strip.gsub(";", '')
      if code == "0"
        flash[:activation_success] = "You have successfully submitted your eCAL lite activation code. An email with the downloaded link to your eCAL lite software will be sent to your inbox shortly. "
        @ecallite.save
        redirect_to ecallite_path
      else
        flash.now[:activation_message] = case code
        when "7", "8", "9", "10", "1"
          "There was an error in processing your request to submit your eCAL lite activation code. Please try entering your activation code again. If you have any further questions about submitting your eCAL lite activations code, please contact support@craftedge.com with your serial number, email address and first and last name"
        when "2"
          "Unfortunately, the activation code entered does not match our records. Please re-enter activation code making sure to enter activation code exactly as it appears on the activation card."
        when "6"
          "We're sorry, the activation code entered has already been activated. Please request a new activation link by providing us the same email address used at the time of activation here "
        else
          "Oops invalid characters found in one or more fields.  Please correct and resubmit."
        end
        render :new
      end
    else
      flash.now[:activation_message] = @ecallite.errors.full_messages.join("</br>")
      render :new
    end
  end
end
