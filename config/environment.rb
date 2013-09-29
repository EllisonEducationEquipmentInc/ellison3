# Load the rails application
require File.expand_path('../application', __FILE__)
#require "sunspot/rails/solr_logging"
# Initialize the rails application
Ellison3::Application.initialize!

include NewRelicWrapper
include EllisonSystem
set_default_locale

# FEDEX credentials

# development
# FEDEX_AUTH_KEY       = 'JEmlc1QzGJCMpaJK'
# FEDEX_SECURITY_CODE  = 'PLDg0CgVXr5EaQVjFcoUrht9l'
# FEDEX_ACCOUNT_NUMBER = '510087380'
# FEDEX_METER_NUMBER   = '118504799'

# production
FEDEX_AUTH_KEY       = 'i4HDMW03YiiNKX6e'
FEDEX_SECURITY_CODE  = 'gRxqSaiOna6wvfAxcFPNO6rrP'
FEDEX_ACCOUNT_NUMBER = '138837459'
FEDEX_METER_NUMBER   = '101341003'


LYRIS_CREDENTIALS = "lyrisaccount@ellison.com:el432lyris"

LYRIS_HQ_PASSWORD = "Lyris_2013_HQ"
