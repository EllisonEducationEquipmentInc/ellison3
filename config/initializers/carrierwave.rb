CarrierWave.configure do |config|
	config.ignore_processing_errors = false
	config.ignore_integrity_errors = false
	config.validate_integrity = true
  config.grid_fs_database = Mongoid.database.name
  config.grid_fs_host = Mongoid.database.connection.primary_pool.host 
  config.grid_fs_port = Mongoid.database.connection.primary_pool.port
  config.storage = :grid_fs
  config.grid_fs_access_url = "/grid"
end