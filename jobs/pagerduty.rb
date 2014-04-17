require 'faraday'
require 'json'

triggered = 0

data_file = 'secrets.json'
parsed_data = JSON.parse( IO.read( data_file ))

url = parsed_data['url']
api_key = parsed_data['api_key']
services = {}
parsed_data['services'].each do |key, value|
  services[key] = value
end

# Pagerduty on-call
SCHEDULER.every '10s' do
  conn = Faraday.new(:url => "#{url}") do |faraday|
    faraday.request :url_encoded
    faraday.adapter Faraday.default_adapter
    faraday.headers['Content-type'] = 'application/json'
    faraday.headers['Authorization'] = "Token token=#{api_key}"
  end

  response = conn.get "/api/v1/escalation_policies/on_call?query=Advanced Business - Default"
  json = JSON.parse(response.body)

  $stdout.puts "ESCALATION POLICIES"
  $stdout.puts json["escalation_policies"]

  user_id =  json["escalation_policies"][0]["on_call"][0]["user"]["id"]

  $stdout.puts "=============Start Users=============="
  users = []
  json["escalation_policies"][0]["on_call"].each_with_index do |item,idx|
    users.push(json["escalation_policies"][0]["on_call"][idx]["user"]["name"])
  end
  $stdout.puts users.join(",")
  $stdout.puts "=============End Users=============="

  response = conn.get "/api/v1/users/#{user_id}"
  json = JSON.parse(response.body)
  user_name = json["user"]["name"]
  gravatar = json["user"]["avatar_url"]

  send_event("on-call", { text: user_name, image: gravatar }) 
  send_event("on-call-tree", { text: users.join(" => ") }) 

end

# Pagerduty Events
SCHEDULER.every '10s' do
  services.each do |key, value|

    conn = Faraday.new(:url => "#{url}") do |faraday|
      faraday.request :url_encoded
      # faraday.response :logger
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
      faraday.headers['Authorization'] = "Token token=#{api_key}"
    end

    response = conn.get "/api/v1/services/#{value}"
    json = JSON.parse(response.body)

    triggered = json["service"]["incident_counts"]["triggered"]
    acknowledged = json["service"]["incident_counts"]["acknowledged"]
    #resolved = json["service"]["incident_counts"]["resolved"]
    #last_incident = json["service"]["last_incident_timestamp"]

    send_event("#{key}-triggered", { value: triggered}) 
    send_event("#{key}-acknowledged", { value: acknowledged})
  end
end