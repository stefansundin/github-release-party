require_relative "github-release-party/version"
require "net/http"
require "json"

class GithubReleaseParty
  def self.releases
    releases = []
    page = 1
    while true
      r = GitHub.get("/repos/#{repo}/releases?page=#{page}")
      unless r.success?
        puts "Error occurred when fetching releases:"
        puts error(r)
        abort
      end
      break if r.json.length == 0
      releases = releases + r.json
      page += 1
    end
    return releases
  end

  def self.update(release_id, name, message)
    r = GitHub.patch("/repos/#{repo}/releases/#{release_id}", {
      name: name,
      body: message,
    }.to_json)
    if r.success?
      puts "GitHub release #{name} updated!"
    else
      puts "Failed to update GitHub release #{name}!"
      puts error(r)
    end
  end

  def self.create(tag_name, message)
    body = {
      tag_name: tag_name,
      name: tag_name,
      body: message,
    }

    r = GitHub.post("/repos/#{repo}/releases", body.to_json)
    if r.success?
      puts "GitHub release #{tag_name} created!"
    else
      puts error(r)
      puts
      puts "Body sent: #{body.to_json}"
      puts
      puts "Failed to create a GitHub release!"
      puts "Create it manually here: https://github.com/#{repo}/releases/new?tag=#{tag_name}"
      puts "Tag version: #{tag_name}"
      puts "Release title: #{tag_name}"
      puts "Message:"
      puts message
    end
  end

  def self.check_env!
    unless ENV["GITHUB_RELEASE_TOKEN"]
      abort "Configure GITHUB_RELEASE_TOKEN to create GitHub releases. See https://github.com/stefansundin/github-release-party#setup"
    end
    unless repo
      abort "Can't find the GitHub repository. Please use the remote 'origin'."
    end
    r = GitHub.get("/user")
    if r.success?
      puts "Creating GitHub release with user #{r.json["login"]}."
    else
      puts "Error authenticating with GitHub. Your token may have expired."
      puts r.body
      abort
    end
  end

  def self.repo
    @repo ||= `git remote -v`.scan(/^origin\t.*github\.com[:\/](.+)\.git /).uniq.flatten.first
  end

  private

  def self.error(r)
    "#{r.request_uri}: #{r.code}: #{r.body}\nHeaders: #{r.headers.to_json}"
  end

  class GitHub
    def self.get(*args)
      request(:request_get, *args)
    end

    def self.post(*args)
      request(:request_post, *args)
    end

    def self.patch(*args)
      request(:patch, *args)
    end

    private

    def self.request(method, request_uri, body=nil)
      opts = {
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 10,
      }
      Net::HTTP.start("api.github.com", 443, opts) do |http|
        headers = {
          "Authorization" => "token #{ENV["GITHUB_RELEASE_TOKEN"]}",
          "User-Agent" => "github-release-party/#{GithubReleaseParty::VERSION}",
        }
        if method == :request_post or method == :patch
          response = http.send(method, request_uri, body, headers)
        else
          response = http.send(method, request_uri, headers)
        end
        return HTTPResponse.new(response, request_uri)
      end
    end
  end

  class HTTPResponse
    def initialize(response, request_uri)
      @response = response
      @request_uri = request_uri
    end

    def request_uri
      @request_uri
    end

    def body
      @response.body
    end

    def json
      @json ||= JSON.parse(@response.body)
    end

    def headers
      @response.to_hash
    end

    def code
      @response.code.to_i
    end

    def success?
      @response.is_a?(Net::HTTPSuccess)
    end
  end
end
