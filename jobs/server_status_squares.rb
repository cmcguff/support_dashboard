#!/usr/bin/env ruby
require 'net/http'
require 'uri'
httptimeout = 60
ping_count = 10

# get list of available sites from the API every 30m or so
apilist = [] 
SCHEDULER.every '30m', :first_in => 0 do |job|
	uri = URI.parse('http://restapi.dev.natasha.myob.co.nz/StackWebSites')
	http = Net::HTTP.new(uri.host, uri.port)
	http.read_timeout = httptimeout
	request = Net::HTTP::Get.new(uri.request_uri)
	response = http.request(request)
	apilist = []
	if response.code == "200"
		JSON.parse(response.body).each do |item|
			apilist.push({sites: item['WebSiteUrlList'], web_site_version: item['WebSiteVersion'], rds_stack_name: item['RdsStackName'], web_stack_name: item['WebStackName'], web_site_name: item['WebSiteName'] })
		end
	end
end

# check status of sites every minute
SCHEDULER.every '1m', :first_in => 0 do |job|
	$stdout.puts "Processing list of servers"
	$stdout.puts apilist.count
	$stdout.puts apilist
	servers = [
		{name: 'sss-mystaffinfo', url: 'https://mystaffinfo.myob.com', method: 'http', web_site_name: 'MyStaffInfo Production'},
		{name: 'sss-relayA', url: 'https://54.206.111.214:443/ping', method: 'http', web_site_name: 'EXO Relay A'},
		{name: 'sss-relayB', url: 'https://54.252.208.125:443/ping', method: 'http', web_site_name: 'EXO Relay B'},
	]
	apilist.each_with_index do |item, idx|
		site = item[:sites][0]
		$stdout.puts site
		
		check_prefix = "http://"
		check_domain = site['DomainName']
		check_suffix = "/Frames/Login.aspx?ReturnUrl=%2f"
		check_url = check_prefix + check_domain + check_suffix
		$stdout.puts check_url
		
		status_board = 'url-status-' + idx.to_s
		$stdout.puts status_board

		webstack = apilist

		servers.push({name: status_board, url: check_url, method: 'http', web_site_name: item[:web_site_name], web_stack_name: item[:web_stack_name], rds_stack_name: item[:rds_stack_name], web_site_version: item[:web_site_version]})
	end

	servers.each do |server|
		if server[:method] == 'http'
			begin
				uri = URI.parse(server[:url])
				http = Net::HTTP.new(uri.host, uri.port)
				http.read_timeout = httptimeout
				if uri.scheme == "https"
					http.use_ssl=true
					http.verify_mode = OpenSSL::SSL::VERIFY_NONE
				end
				request = Net::HTTP::Get.new(uri.request_uri)
				response = http.request(request)
				if response.code == "200"
					result = 1
				else
					result = 0
				end
				rescue Timeout::Error
					result = 0
				rescue Errno::ETIMEDOUT
					result = 0
				rescue Errno::EHOSTUNREACH
					result = 0
				rescue Errno::ECONNREFUSED
					result = 0
				rescue SocketError => e
					result = 0
			end
		elsif server[:method] == 'ping'
			result = `ping -q -c #{ping_count} #{server[:url]}`
			if ($?.exitstatus == 0)
				result = 1
			else
				result = 0
			end
		end
 
		send_event(server[:name], result: result, web_site_name: server[:web_site_name], web_stack_name: server[:web_stack_name], rds_stack_name: server[:rds_stack_name], web_site_version: server[:web_site_version])

	end
end