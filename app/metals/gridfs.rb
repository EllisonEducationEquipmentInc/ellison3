# rails metal to be used with carrierwave (gridfs) and MongoMapper

require 'mongo'

# Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

class Gridfs
  def self.call(env)
    if env["PATH_INFO"] =~ /^\/grid\/(.+)$/
      gridfs_path = $1
      begin
        Mongo::GridFileSystem.new(Mongoid.database).open(gridfs_path, 'r') do |gridfs_file|
          etag = Digest::SHA1.hexdigest("#{gridfs_file.file_length}#{gridfs_file.upload_date.httpdate}")
          fresh = true
          if modified_since = env['HTTP_IF_MODIFIED_SINCE']
            fresh = false if gridfs_file.upload_date <= Time.parse(modified_since)
          end

          if etags = env['HTTP_IF_NONE_MATCH']
            etags = etags.split(/\s*,\s*/)
            fresh = false if etags.include?(etag) || etags.include?('*')
          end
          
          response_headers = {'Content-Type' => gridfs_file.content_type, "Connection" => "keep-alive", "ETag" => etag,
              "Cache-Control" => "public, max-age=315360000", "Date" => Time.now.httpdate, "Last-Modified" => gridfs_file.upload_date.httpdate}
              
          if fresh
            response_headers["Content-Length"] = "#{gridfs_file.file_length}"
            [200, response_headers, [gridfs_file.read]]
          else
            return [304, response_headers, []]
          end
        end  
      rescue Exception => e
        [404, {'Content-Type' => 'text/plain'}, ["File not found. #{e}"]]
      end
    else
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    end
  end
end