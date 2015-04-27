# github-release-party [![Gem Version](https://badge.fury.io/rb/github-release-party.svg)](https://rubygems.org/gems/github-release-party) [![RSS](https://stefansundin.github.io/img/feed.png)](https://github.com/stefansundin/github-release-party/releases.atom)

> Automatically create GitHub releases when you deploy.

I use this gem to automatically create GitHub releases when I deploy to Heroku. Creating releases helps your users/coworkers/boss to keep up with what's new.

All GitHub repositories have release feeds, so I recommend that you direct people to it from your README. E.g:

- [Release feed](https://github.com/stefansundin/github-release-party/releases.atom)

The gem includes rake tasks to deploy to Heroku, but you may choose to only use the class. Please submit any improvements as issues.

*Note:* If you have the heroku gem installed, please uninstall it as it will interfere. Note that the gem is the obsolete now and you should be using the Heroku toolbelt.

```bash
gem uninstall heroku -ax
```


## Installation

### Setup

You first need to get a GitHub token to create the releases. Use [this script](https://gist.github.com/stefansundin/85b9969ab8664b97b7cf) to get one.

You have to create a GitHub application to get a token. Keep your token secure (don't put it in public repos).

You need to put the token into the environment variable `GITHUB_RELEASE_TOKEN`. A good place to do this is in your `.bash_profile`:

```bash
export GITHUB_RELEASE_TOKEN=token12345
```

### App

Add the gem to your Gemfile:

```ruby
group :development do
  gem "github-release-party", "~> 0.0.1"
end
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

When deploying, a tag `heroku/vXX` (where XX is the Heroku version number) will be created, and after it has been pushed, a GitHub release will be created for it.

`rake deploy:force` does the exact same thing, but it forces the Git push to Heroku.

`rake deploy:tag` can be run if you pushed to Heroku manually.

If this gem updates the format it uses for the releases, you can run `rake retag` to update the text in the releases. This command does not go out to heroku and fetch the list of releases there, it only updates the releases based on your tags. To backfill from Heroku data, see [#backfill](#backfille).


## Backfill

The command `heroku releases` is limited to 50 releases, but the API supports getting all of them. This procedure is tested with heroku-toolbelt 3.32.0.

We will use the heroku toolbelt to easily get the list of releases and hashes. Make sure you're logged in (`heroku auth:whoami`).

The code below will output a list of `git tag` commands that you can run to build your tags.

Go into `irb` and run:

```ruby
app = "YOUR_HEROKU_APPNAME"
require "base64"
key = `heroku auth:token`.strip

require "httparty"
response = HTTParty.get("https://api.heroku.com/apps/#{app}/releases",
  headers: {
    "Authorization" => "Basic #{Base64.encode64(':'+key)}".strip,
    "Accept" => "application/vnd.heroku+json; version=3"
  }
)
deploys = response.parsed_response.select { |r| r["description"].start_with?("Deploy ") }
puts deploys.map { |r| "GIT_COMMITTER_DATE='#{r["created_at"]}' git tag heroku/v#{r["version"]} " + r["description"][/[0-9a-f]{7}/] }.join("\n")
```

When you have created all the tags, run `rake retag` to add the tag message and create the releases.
