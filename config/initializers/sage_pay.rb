module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SagePayGateway < Gateway
      self.ssl_version = :TLSv1
    end
  end
end

