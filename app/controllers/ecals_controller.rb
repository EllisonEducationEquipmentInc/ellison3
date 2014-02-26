class EcalsController < ApplicationController

  def new
    @ecallite = EcalActivation.new
  end

  def create
    @ecallite = EcalActivation.new params[:ecal_activation]
    if @ecallite.save

    else
      
    end
  end
end
