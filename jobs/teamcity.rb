require 'teamcity'

def update_builds(build_id, branch_id)
  builds = []
  build = TeamCity.builds(count: 1, buildType: build_id, running: 'any', branch: branch_id).first rescue nil
  #http://teamcity:88/httpAuth/app/rest/builds/id:$LastBuildId_").build
  #startDate = TeamCity..dateTimeFormat.parseDateTime(build.startDate)
  #puts startDate.to_s

  #Get All Branches for Build Configuration
  #builds = TeamCity.builds(locator: 'branch', default: 'any')
  #http://teamcity:88/httpAuth/app/rest/builds?locator: branch:default:any


  unless build.nil?
    value = build.status

    if build.state == "running"
      value =  "Running #{build.percentageComplete}%"
    end

    build_info = {
        label: "Build #{build.number}",
        #value + " on #{date.day}/#{date.month} at #{date.hour}:#{date.min}",
        value: value,
        status: build.status,
        state: build.state,
        branch: build.branchName,
        percent: build.percentageComplete
    }
  else
    build_info = { value: "No Builds Available", branch: branch_id, percent: 10, status: "started" }
  end
  builds << build_info
  builds
end #def

config_file = File.dirname(File.expand_path(__FILE__)) + '/../config/teamcity.yml'
config = YAML::load(File.open(config_file))

TeamCity.configure do |c|
  c.endpoint = config["api_url"]
  c.http_user = config["http_user"]
  c.http_password = config["http_password"]
end

SCHEDULER.every("10s", first_in: '1s') do
  unless config["repositories"].nil?

   # builds = TeamCity.builds(locator: 'branch', default: 'any')
    #builds.each do |data_id, details|
    config["repositories"].each do |data_id, details|

      puts "build_id: " + details["build_id"].to_s
      puts "branch_id: " + details["branch_id"].to_s

      send_event(data_id, { items: update_builds(details["build_id"], details["branch_id"])})
    end
  else
    puts "No TeamCity repositories found :("
  end
end

