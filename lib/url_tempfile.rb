require 'openssl'
require 'tempfile'

# This class provides a Paperclip plugin compliant interface for an "upload" file
# where that uploaded file is actually coming from a URL.  This class will download
# the file from the URL and then respond to the necessary methods for the interface,
# as required by Paperclip so that the file can be processed and managed by
# Paperclip just as a regular uploaded file would.
#
class URLTempfile < Tempfile
  class UnsuccessfulHTTPResponse < StandardError
    attr_reader :http_response, :url

    def initialize(url, http_response)
      @url, @http_response = url, http_response
      super("The request to #{url} was unsuccessful.  Response status: #{http_response.code}")
    end
  end

  BUFFER_SIZE = 1024

  attr :content_type
  attr_reader :original_filename

  def initialize(url)
    @url = URI.parse(url)

    super('urlupload')

    fetch(@url) do |url, res|
      raise UnsuccessfulHTTPResponse.new(url, res) unless res.code.to_s =~ /^2\d\d$/

      res.read_body do |segment|
        self.write(segment)
      end

      @content_type = res.content_type

      # Take the URI path and strip off everything after last slash, assume this
      # to be filename (URI path already removes any query string)
      @original_filename = url.path.split('/').last;
    end

    self.flush
  end

  private

  def fetch(uri, limit = 10, &block)
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    http(uri).request_get(uri.request_uri) do |response|
     case response
        when Net::HTTPSuccess     then yield uri, response
        when Net::HTTPRedirection then fetch(URI.parse(response['location']), limit - 1, &block)
        else raise UnsuccessfulHTTPResponse.new(uri, response)
      end
    end
  end

  def http(uri) #:nodoc:
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.is_a?(URI::HTTPS)
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end
end
