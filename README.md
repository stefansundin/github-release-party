# github-release-party [![Gem Version](https://badge.fury.io/rb/github-release-party.svg)](https://rubygems.org/gems/github-release-party) [![RSS](https://stefansundin.github.io/img/feed.png)](https://github.com/stefansundin/github-release-party/releases.atom)

> Automatically create GitHub releases when you deploy.

I use this gem to automatically create GitHub releases when I deploy to Heroku. Creating releases helps your users/coworkers/boss to keep up with what's new.

The gem includes rake tasks to deploy to Heroku. Please submit any improvements as issues.

Example result:
- Release page: https://github.com/stefansundin/github-activity/releases
- RSS Feed: https://github.com/stefansundin/github-activity/releases.atom


## Installation

### Setup

You first need to [create a GitHub access token](https://github.com/settings/tokens) to create the releases (limit the scope to `repo`). Keep your token secure (don't put it in public repos).

You need to set the environment variable `GITHUB_RELEASE_TOKEN` to token. A good place to do this is in your `.bash_profile`:

```bash
export GITHUB_RELEASE_TOKEN=token12345
```

In normal use, the Heroku toolbelt is not required. The release number is read from the git push output. Your Heroku remote must be named `heroku`.

### App

Add the gem to your Gemfile:

```ruby
group :development do
  gem "github-release-party", "~> 0.2.0"
end
```

This gem is cryptographically signed, you can verify the installation with:

```bash
gem cert --add <(curl -Ls https://raw.githubusercontent.com/stefansundin/github-release-party/master/certs/stefansundin.pem)
gem install github-release-party -P MediumSecurity
```

Require it in your Rakefile:

```ruby
environment = ENV["RACK_ENV"] || "development"
if environment == "development"
  require "github-release-party/tasks/heroku"
end
```

Then deploy with:

```bash
rake deploy
```

You also get `rake deploy:force`, `rake deploy:tag`, and `rake deploy:retag`.

When deploying, a tag `heroku/vXX` (where XX is the Heroku version number) will be created, and then a GitHub release will be created for it.

`rake deploy:force` does the exact same thing, but it forces the Git push to Heroku.

`rake deploy:tag` can be run if you pushed to Heroku manually. You need to have the Heroku toolbelt installed in order to use this command.

If this gem updates the message format it uses for the releases, you can run `rake deploy:retag` to update the text in the tags and releases. This command does not go out to Heroku and fetch the list of releases there, it only updates the releases based on your tags. To backfill from Heroku data, see below.


## Backfill

The command `heroku releases` is limited to 50 releases, but the API supports getting all of them. This procedure is tested with heroku-toolbelt 3.32.0. Make sure you're logged in with the toolbelt (`heroku auth:whoami`).

The code below will output a list of `git tag` commands that you can run to build your tags.

Go into `irb` and run:

```ruby
app = "YOUR_HEROKU_APPNAME"
key = `heroku auth:token`.strip

require "base64"
require "net/http"
require "json"

def http_get(url, headers)
  uri = URI.parse(url)
  Net::HTTP.start(uri.host, uri.port, {
    use_ssl: uri.scheme == "https",
  }) do |http|
    endpoint = uri.path
    endpoint += "?#{uri.query}" if uri.query
    endpoint += "##{uri.fragment}" if uri.fragment
    return http.request_get(endpoint, headers)
  end
end

response = http_get("https://api.heroku.com/apps/#{app}/releases", {
  "Authorization" => "Basic #{Base64.encode64(':'+key).strip}",
  "Accept" => "application/vnd.heroku+json; version=3",
  "Range" => "; max=1000",
})

data = JSON.parse(response.body)
deploys = data.select { |r| r["description"].start_with?("Deploy ") }
puts deploys.map { |r| "GIT_COMMITTER_DATE='#{r["created_at"]}' git tag heroku/v#{r["version"]} " + r["description"][/[0-9a-f]{7}/] }.join("\n")
```

When you have created all the tags, run `rake deploy:retag` to add the tag message and create the releases.

## Heroku toolbelt

The [Heroku toolbelt](https://toolbelt.heroku.com/) is only needed for `rake deploy:tag` and backfilling data as described above.

If you have the legacy Heroku gem installed, please uninstall it as it will not work properly with this gem.

```bash
gem uninstall heroku -ax
```
