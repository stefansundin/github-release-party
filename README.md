# github-release-party

> Automatically create GitHub releases when you deploy.

I use this gem to automatically create GitHub releases when I deploy. Creating releases helps your users/coworkers/boss to keep up with what's new.

The gem includes rake tasks to deploy to Fly and Heroku. Please submit any improvements as issues.

Example result:
- Release page: https://github.com/stefansundin/rssbox/releases
- RSS Feed: https://github.com/stefansundin/rssbox/releases.atom


## Installation

### Setup

You need to provide a GitHub access token so that the gem can create the GitHub release after the deployment has finished. There are two different kinds of GitHub access tokens:
- The recommended token is [a fine-grained token](https://github.com/settings/personal-access-tokens). Add only the repositories required and grant `Read and write` access to "Contents" only.
- You can also create [a classic token](https://github.com/settings/tokens). Limit the scope to `repo`.

**Keep your token secure! Don't commit it to a public repo!**

You need to set the environment variable `GITHUB_RELEASE_TOKEN` with the token as the value. A good place to do this is in your `.bash_profile`:

```bash
export GITHUB_RELEASE_TOKEN=token12345
```

### App

Add the gem to your Gemfile:

```ruby
group :development do
  gem "github-release-party", require: false
end
```

This gem is cryptographically signed, you can verify the installation with:

```bash
gem cert --add <(curl -Ls https://raw.githubusercontent.com/stefansundin/github-release-party/main/certs/stefansundin.pem)
gem install github-release-party -P MediumSecurity
```

Require the `fly` task in your `Rakefile`:

```ruby
environment = ENV["APP_ENV"] || ENV["RACK_ENV"] || "development"
if environment == "development"
  require "github-release-party/tasks/fly"
end
```

Then deploy with:

```bash
rake deploy
```

You also get `rake deploy:force`, `rake deploy:tag`, and `rake deploy:retag`.

When deploying, a tag `fly/vXXX` (where `XXX` is the Fly version number) will be created, and then a GitHub release will be created for it.

`rake deploy:tag` can be run if you deployed to fly manually.

If this gem updates the message format it uses for the releases, you can run `rake deploy:retag` to update the text in the tags and releases.

### Heroku

_Note: I no longer use Heroku so there are no guarantees that this will continue to work._

Require the `heroku` task in your `Rakefile`:

```ruby
environment = ENV["APP_ENV"] || ENV["RACK_ENV"] || "development"
if environment == "development"
  require "github-release-party/tasks/heroku"
end
```

In normal use, the Heroku toolbelt is not required. The release number is read from the git push output. Your Heroku remote must be named `heroku`.
