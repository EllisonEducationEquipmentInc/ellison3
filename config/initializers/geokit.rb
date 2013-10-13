conf = YAML.load File.open(Rails.root + "config/gmaps_api_key.yml")

Geokit::Geocoders::provider_order = [:google3, :us]
Geokit::Geocoders::google = conf["development"]
