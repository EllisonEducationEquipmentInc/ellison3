require 'mongo'

class GridfsController < ActionController::Metal
  def serve
    gridfs_path = env["PATH_INFO"].gsub("/grid/", "")
    begin
      Mongo::GridFileSystem.new(Mongoid.database).open(gridfs_path, 'r') do |gridfs_file|
        self.response_body = gridfs_file.read
        self.content_type = gridfs_file.content_type
        self.headers.merge!("Content-Length" => gridfs_file.file_length.to_s, "Cache-Control" => "max-age=315360000", "Date" => Time.now.httpdate, "Last-Modified" => gridfs_file.upload_date.httpdate)
      end
    rescue
      self.status = :file_not_found
      self.content_type = 'text/plain'
      self.response_body = ''
    end
  end
end
