require File.expand_path("../lib/github-release-party/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "github-release-party"
  s.version     = GithubReleaseParty::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stefan Sundin"]
  s.email       = ["rubygems@stefansundin.com"]
  s.homepage    = "https://github.com/stefansundin/github-release-party"
  s.summary     = "Easily create GitHub releases."
  s.description = "I use this gem to automatically create GitHub releases when I deploy to Heroku. See the GitHub page for usage."
  s.license     = "GPL-3.0"

  s.cert_chain  = ["certs/stefansundin.pem"]
  s.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/

  s.required_rubygems_version = ">= 1.3.6"

  s.add_development_dependency "rake", "~> 12"

  s.files        = `git ls-files`.split("\n").select { |f| f.start_with?("lib/") }
  s.executables  = `git ls-files`.split("\n").map { |f| f =~ /^bin\/(.*)/ ? $1 : nil }.compact
  s.require_path = 'lib'
end