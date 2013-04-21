conf = YAML.load File.open(Rails.root + "config/gmaps_api_key.yml")

Geokit::Geocoders::google = conf["development"]
