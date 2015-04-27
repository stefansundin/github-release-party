require "github-release-party"

desc "Deploy new version to Heroku"
task :deploy do
  return unless GithubReleaseParty.env_ok
  success = system "git push heroku HEAD:master"
  if not success
    abort "Deploy failed."
  end
  Rake.application.invoke_task("deploy:tag")
end

namespace :deploy do
  desc "Forcibly deploy new version to Heroku"
  task :force do
    return unless GithubReleaseParty.env_ok
    success = system "git push heroku HEAD:master --force"
    if not success
      abort "Deploy failed."
    end
    Rake.application.invoke_task("deploy:tag")
  end

  desc "Tag latest release"
  task :tag do
    return unless GithubReleaseParty.env_ok

    # get heroku version number
    ver = `heroku releases`.split("\n")[1].split(" ")[0]
    hash = `git rev-parse HEAD`.strip
    tag_name = "heroku/#{ver}"

    # build tag message
    repo = GithubReleaseParty.repo
    last_tag = `git describe --tags --abbrev=0 --match 'heroku/v*'`.strip
    commits = `git log #{last_tag}..#{hash} --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
    message = "Deploy #{hash[0..6]}\n\nDiff: https://github.com/#{repo}/compare/#{last_tag}...#{tag_name}\n#{commits}"

    # tag and push new tag
    puts "Tagging #{tag_name}."
    success = system "git tag -a -m \"#{message.gsub('"','\\"')}\" #{tag_name} #{hash}"
    abort if not success
    success = system "git push origin #{tag_name}"
    abort if not success

    # create GitHub release
    puts
    puts "Waiting 3 seconds to let GitHub process the new tag."
    sleep 3
    GithubReleaseParty.create(tag_name, ver, message)
  end
end

desc "Rebuild all the release tags"
task :retag do
  github = GithubReleaseParty.new
  repo = GithubReleaseParty.repo

  tags = `git tag -l heroku/v* --sort=version:refname`.split("\n")
  puts "Found #{tags.count} tags."
  tags.each_with_index do |tag_name, i|
    ver = tag_name[/v(\d+)/]
    last_tag = if i == 0
      `git rev-list --max-parents=0 HEAD`.strip
    else
      tags[i-1]
    end

    hash = `git rev-list --max-count=1 #{tag_name}`.strip
    date = `git show --pretty="format:%ai" -s --no-color #{tag_name} | tail -1`.strip
    commits = `git log #{last_tag}..#{tag_name} --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
    message = "Deploy #{hash[0..6]}\n\nDiff: https://github.com/#{repo}/compare/#{last_tag}...#{tag_name}\n#{commits}"

    if i == 0
      message += "\n"+`git show #{last_tag} -s --pretty=format:"- [%s](https://github.com/#{repo}/commit/%H)"`
    end

    success = system "GIT_COMMITTER_DATE='#{date}' git tag -f -a -m \"#{message.gsub('"','\\"')}\" #{tag_name} #{tag_name}^{}"
    abort if not success
    success = system "git push -f origin #{tag_name}"
    abort if not success

    # update or create GitHub release
    github.update_or_create(tag_name, ver, message)
  end

  puts "Done"
end
