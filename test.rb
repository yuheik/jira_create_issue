#! /usr/bin/env ruby

require './jira'
require './jira_api_caller'
require './search_query_builder'

puts "----------------------------------------"
sp_to_set = rand(1..30)
puts "update #{sp_to_set}"
param_hash = Jira::Issue.compose_hash(:story_point => sp_to_set)
p JiraApiCaller.update_issue("MYP-62", param_hash)

puts "----------------------------------------"
puts "get single"
p JiraApiCaller.get_issue("MYP-62")

puts "----------------------------------------"
puts "search"
query = JiraApi::SearchQueryBuilder.build_query({ project: "MYP" })
JiraApiCaller.search(query).sort_by!(:key).each do |issue|
  p issue
end
