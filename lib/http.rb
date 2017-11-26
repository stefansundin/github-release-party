# frozen_string_literal: true

require "net/http"
require "addressable/uri"
require "json"

class HTTP
  def self.request(method, url, options={body: nil, headers: nil, query: nil})
    relative_url = (url[0] == "/")

    if defined?(self::BASE_URL) and relative_url
      url = self::BASE_URL+url
    end

    if defined?(self::PARAMS) and relative_url
      if url["?"]
        url += "&"+self::PARAMS
      else
        url += "?"+self::PARAMS
      end
    end

    if options[:query]
      params = options[:query].map { |k,v| "#{k}=#{v}" }.join("&")
      if url["?"]
        url += "&"+params
      else
        url += "?"+params
      end
    end

    uri = Addressable::URI.parse(url).normalize
    opts = {
      use_ssl: uri.scheme == "https",
      open_timeout: 10,
      read_timeout: 10,
    }
    Net::HTTP.start(uri.host, uri.port, opts) do |http|
      headers = {}
      headers.merge!(self::HEADERS) if defined?(self::HEADERS) and relative_url
      headers.merge!(options[:headers]) if options[:headers]
      if method == :request_post or method == :patch
        response = http.send(method, uri.request_uri, options[:body], headers)
      else
        response = http.send(method, uri.request_uri, headers)
      end
      return HTTPResponse.new(response, uri.to_s)
    end
  end

  def self.get(*args)
    request(:request_get, *args)
  end

  def self.post(*args)
    request(:request_post, *args)
  end

  def self.patch(*args)
    request(:patch, *args)
  end
end

class HTTPResponse
  def initialize(response, url)
    @response = response
    @url = url
  end

  def raw
    @response
  end

  def url
    @url
  end

  def body
    @response.body
  end

  def json
    @json ||= JSON.parse(@response.body)
  end

  def parsed_response
    json
  end

  def headers
    @response.header
  end

  def code
    @response.code.to_i
  end

  def success?
    @response.is_a?(Net::HTTPSuccess)
  end

  def redirect?
    @response.is_a?(Net::HTTPRedirection)
  end

  def redirect_url
    raise("not a redirect") if !redirect?
    url = @response.header["location"]
    if url[0] == "/"
      # relative redirect
      uri = Addressable::URI.parse(@url)
      url = uri.scheme + "://" + uri.host + url
    elsif /^https?:\/\/./ !~ url
      raise("bad redirect: #{url}")
    end
    Addressable::URI.parse(url).normalize.to_s # Some redirects do not url encode properly, such as http://amzn.to/2aDg49F
  end

  def redirect_same_origin?
    return false if !redirect?
    uri = Addressable::URI.parse(@url).normalize
    new_uri = Addressable::URI.parse(redirect_url).normalize
    uri.origin == new_uri.origin
  end
end

class HTTPError < StandardError
  def initialize(obj)
    @obj = obj
  end

  def request
    @obj
  end

  def data
    @obj.json
  end

  def message
    "#{@obj.code}: #{@obj.body}"
  end
end
