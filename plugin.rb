# name: GitHub bugs
# about: Assign users badges based on GitHub bug reports
# version: 1.0
# authors: Jakob Borg

require('net/http')
require('uri')
require('json')

module ::GithubBugs
  def self.badge_grant!
    return unless SiteSetting.github_bugs_repo.present?

    unless badge = Badge.find_by(name: 'Bug Reporter')
      badge = Badge.create!(name: 'Bug Reporter',
       description: 'Created an issue on GitHub',
       badge_type_id: 3)
    end

    uri = URI.parse("https://api.github.com/repos/#{SiteSetting.github_bugs_repo}/issues?filter=all&state=all&per_page=100")
    response = Net::HTTP.get_response(uri)
    issues = JSON.parse(response.body)

    names = issues.group_by{|i| i['user']['url'].sub('https://api.github.com/users/', '')}.keys


    names.each do |name|
      user = User.find_by(username: name)

      if user
        BadgeGranter.grant(badge, user)
        if user.title.blank?
          user.title = badge.name
          user.save
        end
      end
    end
  end
end

after_initialize do
  module ::GithubBugs
    class UpdateJob < ::Jobs::Scheduled
      every 1.day

      def execute(args)
        GithubBugs.badge_grant!
      end
    end
  end
end
