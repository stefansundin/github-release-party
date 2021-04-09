require "open3"
require "shellwords"
require "github-release-party"

def heroku_push(args=[])
  # grab the new version number from the Heroku push output
  cmd = %w[git push heroku HEAD:master] + args
  ver = Open3.popen2e(*cmd) do |stdin, output, thread|
    v = nil
    output.each do |line|
      puts line
      if /Released (v\d+)/ =~ line
        v = $~[1]
      end
    end
    v
  end
  return ver
end

def github_tag(hash, ver)
  # build tag message
  repo = GithubReleaseParty.repo
  tag_name = "heroku/#{ver}"
  last_tag = `git describe --tags --abbrev=0 --match 'heroku/v*' 2> /dev/null`.strip
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
  abort if not success
  puts
  success = system "git push origin #{tag_name}"
  abort if not success

  # create GitHub release
  puts
  puts "Waiting 3 seconds to let GitHub process the new tag."
  sleep(3)
  GithubReleaseParty.create(tag_name, ver, message)
end


desc "Deploy a new version to Heroku"
task :deploy do
  GithubReleaseParty.check_env!
  ver = heroku_push() or abort("Deploy failed.")
  hash = `git rev-parse HEAD`.strip
  github_tag(hash, ver)
end

namespace :deploy do
  desc "Deploy a new version to Heroku using --force"
  task :force do
    GithubReleaseParty.check_env!
    ver = heroku_push(%w[--force]) or abort("Deploy failed.")
    hash = `git rev-parse HEAD`.strip
    github_tag(hash, ver)
  end

  desc "Tag last release"
  task :tag do
    GithubReleaseParty.check_env!

    # get heroku version number
    begin
      heroku_app = `git remote -v`.scan(/^heroku\t.*heroku\.com[:\/](.+)\.git /).uniq.flatten.first
      ver = `heroku releases --app '#{heroku_app}'`.split("\n")[1].split(" ")[0]
      hash = `git rev-parse HEAD`.strip
    rescue
      abort "There was a problem getting the release number. Have you logged in with the Heroku cli? Try again with 'rake deploy:tag'."
    end

    github_tag(hash, ver)
  end

  desc "Rebuild all the release tags"
  task :retag do
    GithubReleaseParty.check_env!
    releases = GithubReleaseParty.releases
    repo = GithubReleaseParty.repo

    tags = `git tag -l heroku/v* --sort=version:refname`.split("\n")
    puts "Found #{tags.length} tags."
    tags.each_with_index do |tag_name, i|
      puts
      ver = tag_name[/v(\d+)/]
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
      abort if not success
      success = system "git push -f origin #{tag_name}"
      abort if not success

      # update or create GitHub release
      release = releases.find { |rel| rel["tag_name"] == tag_name }
      if release
        GithubReleaseParty.update(release["id"], ver, message)
      else
        GithubReleaseParty.create(tag_name, ver, message)
      end
    end

    puts
    puts "Done"
  end

  desc "List the new commits since last deploy (you might want to pull first to ensure you have the latest tag)"
  task :changes do
    last_tag = `git describe --tags --abbrev=0 --match 'heroku/v*' 2> /dev/null`.strip
    last_tag = `git rev-list --max-parents=0 HEAD`.strip[0..6] if last_tag.empty?
    system "git log --oneline --no-decorate --reverse #{last_tag}..HEAD"
  end
end
