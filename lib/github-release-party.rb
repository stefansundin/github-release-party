require_relative "http"

class GithubReleaseParty < HTTP
  BASE_URL = "https://api.github.com"
  PARAMS = "access_token=#{ENV["GITHUB_RELEASE_TOKEN"]}"
  HEADERS = {
    "User-Agent" => "github-release-party/#{GithubReleaseParty::VERSION}",
  }

  def initialize
    return unless self.class.env_ok
    @releases = []
    page = 1
    while true
      r = self.class.get("/repos/#{self.class.repo}/releases?page=#{page}")
      raise(HTTPError, r) if !r.success?
      break if r.json.length == 0

      @releases = @releases + r.json
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

    r = patch("/repos/#{repo}/releases/#{id}", {
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

    r = post("/repos/#{repo}/releases", {
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
      puts "Create it manually here: https://github.com/#{repo}/releases/new?tag=#{tag_name}"
      puts "Tag version: #{tag_name}"
      puts "Release title: #{tag_name}"
      puts "Message:"
      puts message
    end
  end

  def self.env_ok
    if !ENV["GITHUB_RELEASE_TOKEN"]
      puts "Configure GITHUB_RELEASE_TOKEN to create GitHub releases. See https://github.com/stefansundin/github-release-party#setup"
      return false
    end
    if !repo
      puts "Can't find the GitHub repo. Please use the remote 'origin'."
      return false
    end
    return true
  end

  def self.repo
    @repo ||= `git remote -v`.scan(/^origin\t.*github\.com[:\/](.+)\.git /).uniq.flatten.first
  end

  private

  def self.error(r)
    "#{r.url}: #{r.code}: #{r.body}. #{r.headers.to_json}"
  end
end
