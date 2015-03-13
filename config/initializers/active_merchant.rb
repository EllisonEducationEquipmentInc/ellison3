module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Gestpay
        module Common
          def ssl_get(url, path)
            uri = URI.parse(url)
            site = Net::HTTP.new(uri.host, uri.port)
            site.use_ssl = true
            site.ssl_version = :TLSv1
            site.verify_mode    = OpenSSL::SSL::VERIFY_NONE
            site.get(path).body
          end
        end
      end
    end
  end
end
