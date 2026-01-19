require "open3"
require "shellwords"
require "github-release-party"

def fly_deploy(args=[])
  cmd = %w[fly deploy] + args
  return system(*cmd)
end

def fly_releases()
  data = `fly releases --json`
  abort unless $?.success?
  return JSON.parse(data)
rescue => err
  puts "There was a problem getting the release number."
  puts "The error was: #{err.message}"
  abort
end

def github_tag(hash, ver)
  # build tag message
  repo = GithubReleaseParty.repo
  tag_name = "fly/#{ver}"
  last_tag = `git describe --tags --abbrev=0 --match 'fly/v*' 2> /dev/null`.strip
  if last_tag.empty?
    # first deploy, use root hash
    last_tag = `git rev-list --max-parents=0 HEAD`.strip[0..6]
    first_deploy = true
  end
  commits = `git log #{last_tag}..#{hash} --reverse --first-parent --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
  message = "Deploy #{hash[0..6]}\n\nDiff: https://github.com/#{repo}/compare/#{last_tag}...#{tag_name}\n#{commits}"

  if first_deploy
    message = "#{message.strip}\n"+`git show #{last_tag} -s --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
  end

  # tag and push new tag
  puts
  puts "Tagging #{tag_name}."
  success = system "git tag -a -m #{Shellwords.shellescape(message)} #{tag_name} #{hash}"
  puts "Ignoring error." unless success
  puts
  success = system "git push origin #{tag_name}"
  puts "Ignoring error." unless success

  # create GitHub release
  puts
  puts "Waiting 3 seconds to let GitHub process the new tag."
  sleep(3)
  GithubReleaseParty.create(tag_name, message)
end


desc "Deploy a new version to Fly"
task :deploy do
  GithubReleaseParty.check_env!
  fly_deploy() or abort("Deploy failed.")
  releases = fly_releases()
  ver = "v#{releases[0]["Version"]}"
  hash = `git rev-parse HEAD`.strip
  github_tag(hash, ver)
end

namespace :deploy do
  desc "Tag last release"
  task :tag do
    GithubReleaseParty.check_env!
    releases = fly_releases()
    ver = "v#{releases[0]["Version"]}"
    hash = `git rev-parse HEAD`.strip
    github_tag(hash, ver)
  end

  desc "Rebuild all the release tags"
  task :retag do
    GithubReleaseParty.check_env!
    releases = GithubReleaseParty.releases
    repo = GithubReleaseParty.repo

    tags = `git tag -l fly/v* --sort=version:refname`.split("\n")
    puts "Found #{tags.length} tags."
    tags.each_with_index do |tag_name, i|
      puts
      last_tag = if i == 0
        `git rev-list --max-parents=0 HEAD`.strip
      else
        tags[i-1]
      end

      hash = `git rev-list --max-count=1 #{tag_name}`.strip
      date = `git show --pretty="format:%ai" -s --no-color #{tag_name} | tail -1`.strip
      commits = `git log #{last_tag}..#{tag_name} --reverse --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
      message = "Deploy #{hash[0..6]}\n\nDiff: https://github.com/#{repo}/compare/#{last_tag}...#{tag_name}\n#{commits}"

      if i == 0
        message += "\n"+`git show #{last_tag} -s --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
      end

      success = system "GIT_COMMITTER_DATE='#{date}' git tag -f -a -m #{Shellwords.shellescape(message)} #{tag_name} #{tag_name}^{}"
      abort unless success
      success = system "git push -f origin #{tag_name}"
      abort unless success

      # update or create GitHub release
      release = releases.find { |rel| rel["tag_name"] == tag_name }
      if release
        GithubReleaseParty.update(release["id"], tag_name, message)
      else
        GithubReleaseParty.create(tag_name, message)
      end
    end

    puts
    puts "Done"
  end

  desc "List the new commits since last deploy (you might want to pull first to ensure you have the latest tag)"
  task :changes do
    last_tag = `git describe --tags --abbrev=0 --match 'fly/v*' 2> /dev/null`.strip
    last_tag = `git rev-list --max-parents=0 HEAD`.strip[0..6] if last_tag.empty?
    system "git log --oneline --no-decorate --reverse #{last_tag}..HEAD"
  end
end
