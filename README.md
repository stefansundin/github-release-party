# github-release-party [![Gem Version](https://badge.fury.io/rb/github-release-party.svg)](https://rubygems.org/gems/github-release-party) [![RSS](https://stefansundin.github.io/img/feed.png)](https://github.com/stefansundin/github-release-party/releases.atom)

> Easily create GitHub releases.

I use this gem to automatically create GitHub releases when I deploy to Heroku. Creating releases helps your users/coworkers keep up with what's new.

All GitHub repositories have release feeds, so I recommend that you direct people to it from your README.

There are built-in rake tasks to deploy to Heroku, but you may choose to only use the class. Please submit any improvements as issues.


## Installation

You first need to get a GitHub token to create the releases. Use [this script](https://gist.github.com/stefansundin/85b9969ab8664b97b7cf) to get one.

You are required to create your own GitHub application to get a token. I could have made this easier, but I don't want to know your token. Keep your token secure (don't put it in public repos).

You need to configure the environment variable `GITHUB_RELEASE_TOKEN`. A good place to put it is in your `.bash_profile`:

```bash
export GITHUB_RELEASE_TOKEN=token12345
```

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

`deploy:force` does the exact same thing, but it forces the Git push to Heroku.

`deploy:tag` can be run if the last release wasn't created properly (e.g. your GitHub token was invalid).

If this gem updates the format it uses for the releases, you can run `rake retag` to update the text in the releases. This command does not go out to heroku and fetch the list of releases there, it only updates the releases based on your tags. To backfill from Heroku data, see [#backfill](#backfille).


## Backfill

The command `heroku releases` is limited to 50 releases, but the API supports getting all of them. This procedure is tested with heroku-toolbelt 3.32.0.

We will use the heroku toolbelt to easily get the list of releases and hashes. Make sure you're logged in (`heroku auth:whoami`).

Get the gem and start the console using:

```bash
gem install heroku
irb
```

The code below will output a list of `git tag` commands that you can run to build your tags.

```ruby
require "heroku"
require "heroku/api"
app = "gh-rss"
key = Heroku::Auth.read_credentials[1]
auth = "Basic #{Base64.encode64(':'+key)}".strip

response = Heroku::API.new.request({
  expects: [ 200, 206 ],
  headers: {
    "Authorization" => auth,
    "Accept" => "application/vnd.heroku+json; version=3"
  },
  method:  :get,
  path:    "/apps/#{app}/releases"
})
deploys = response.body.select { |r| r["description"].start_with?("Deploy ") }
puts deploys.map { |r| "GIT_COMMITTER_DATE='#{r["created_at"]}' git tag heroku/v#{r["version"]} " + r["description"][/[0-9a-f]{7}/] }.join("\n")
```

When you have created all the tags, run `rake retag` to add the tag message and create the releases.

Now you have to uninstall the heroku gem, because the deploy task will not function properly if you have the gem installed:

```bash
gem uninstall heroku -ax
```
