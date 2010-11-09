CarrierWave.configure do |config|
	config.ignore_processing_errors = false
  config.grid_fs_database = Mongoid.database.name
  config.grid_fs_host = Mongoid.config.master.connection.host
  config.storage = :grid_fs
  config.grid_fs_access_url = "/grid"
end