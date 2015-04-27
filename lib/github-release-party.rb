# This is a GitHub party, and everyone's invited!

require "httparty"

class GithubReleaseParty
  include HTTParty
  base_uri "https://api.github.com"

  def initialize
    return unless self.class.env_ok
    @releases = []
    page = 1
    while true
      r = self.class.get "/repos/#{self.class.repo}/releases?page=#{page}", self.class.options
      raise self.class.error(r) if not r.success?
      break if r.parsed_response.count == 0

      @releases = @releases + r.parsed_response
      page += 1
    end
  end

  def update_or_create(tag_name, name, message)
    release = @releases.find { |rel| rel["tag_name"] == tag_name }
    if release
      self.class.update(release["id"], name, message)
    else
      self.class.create(tag_name, name, message)
    end
  end

  def self.update(id, name, message)
    return unless env_ok

    r = patch "/repos/#{repo}/releases/#{id}", options.merge({
      body: {
        name: name,
        body: message
      }.to_json
    })
    if r.success?
      puts "GitHub release #{name} updated!"
    else
      puts "Failed to update GitHub release #{tag_name}!"
      puts error(r)
    end
  end

  def self.create(tag_name, name, message)
    return unless env_ok

    body = {
      tag_name: tag_name,
      name: name,
      body: message
    }

    r = post "/repos/#{repo}/releases", options.merge({
      body: body.to_json
    })
    if r.success?
      puts "GitHub release #{tag_name} created!"
    else
      puts error(r)
      puts
      puts "Body sent: #{body.to_json}"
      puts
      puts "Failed to create GitHub release!"
      puts "Create it manually here: https://github.com/#{repo}/releases/new"
      puts "Tag version: #{tag_name}"
      puts "Release title: #{tag_name}"
      puts "Message:"
      puts message
    end
  end

  def self.env_ok
    if not ENV["GITHUB_RELEASE_TOKEN"]
      puts "Configure GITHUB_RELEASE_TOKEN to create GitHub releases. See https://github.com/stefansundin/github-release-party#setup"
      return false
    end
    if not repo
      puts "Can't find the GitHub repo. Please use the remote 'origin'."
      return false
    end
    return true
  end

  def self.repo
    `git remote -v`.scan(/^origin\t.*github.com[:\/](.+)\.git /).uniq.flatten.first
  end

  private

  def self.options
    {
      query: {
        access_token: ENV["GITHUB_RELEASE_TOKEN"]
      },
      headers: {
        "User-Agent" => "github-release-party/#{GithubReleaseParty::VERSION}"
      }
    }
  end

  def self.error(r)
    "#{r.request.path.to_s}: #{r.code} #{r.message}: #{r.body}. #{r.headers.to_h.to_json}"
  end
end
