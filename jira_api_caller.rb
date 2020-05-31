#! /usr/bin/env ruby

require 'json'
require 'benchmark'
require_relative './api_caller_restclient'
require_relative './credentials.rb'
require_relative './jira'

SeachType = :parallel           # or :sequence

class JiraApiCaller < ApiCallerRestClient
  JIRA_URL = "#{Credentials::Site}/rest/api/2"
  INITIAL_SEARCH_SIZE = 1
  MAX_SEARCH_RESULTS  = 5
  # MAX_SEARCH_RESULTS  = 100   # for sequence

  def self.call(url, silent = false)
    body = super("#{JIRA_URL}/#{url}", Credentials::UserName, Credentials::Password, :GET, nil)
    # puts body # dump this to create raw json
    # abort

    json = JSON.parse(body)
    return json
  end

  def self.get_issue(issue_id)
    json = call("issue/#{issue_id}")

    Jira::Issue.new(json)
  end

  def self.search_with_range(query, index, max_num_of_results, silent = false)
    url  = "search?jql=#{URI.escape(query)}"
    url += "&startAt=#{index}"
    url += "&maxResults=#{max_num_of_results}" # setting 'maxResults' will fasten search
    json = call(url, silent)

    return json
  end

  def self.to_issues(json)
    return json["issues"].map { |issue_json| Jira::Issue.new(issue_json) }
  end

  # main purpose is to know whole size
  def self.initial_search_call(query, size)
    json = search_with_range(query, 0, size, false)
    issues = to_issues(json)
    total = json["total"]

    return issues, total
  end

  def self.search_parallel_call(query, start_index, total)
    index   = start_index
    threads = Array.new
    results = Array.new
    i = 0

    loop do
      results[i] = Array.new

      threads << Thread.new(query, index, results[i]) do | query, index, results |
        json = search_with_range(query, index, MAX_SEARCH_RESULTS, true)
        results << to_issues(json)
      end

      break if index + MAX_SEARCH_RESULTS >= total
      index += MAX_SEARCH_RESULTS
      i = i + 1
    end

    threads.each { |thread| thread.join }

    return results.flatten!
  end

  def self.search(query)
    return search_in_parallel(query)
    # return search_in_sequence(query) # Leave this for debug.
  end

  def self.search_in_parallel(query)
    puts "search with query: #{query}"
    puts ""

    issues = Array.new
    total  = 0

    benchmark_result = Benchmark.realtime do
      benchmark_first_request = Benchmark.realtime do
        issues, total = initial_search_call(query, INITIAL_SEARCH_SIZE)
      end

      puts "#{issues.size} / #{total} completed. (init request : #{benchmark_first_request.floor}s)"
      puts ""

      issues += search_parallel_call(query, INITIAL_SEARCH_SIZE, total) if (issues.size < total)
    end

    puts "#{issues.size} / #{total} completed. (total sequence : #{benchmark_result.floor}s)"
    puts ""

    return issues
  end

  def self.search_in_sequence(query)
    puts "search with query: #{query}"
    puts ""

    issues = Array.new

    benchmark_result = Benchmark.realtime do
      index = 0
      loop do
        json = search_with_range(query, index, MAX_SEARCH_RESULTS)
        json["issues"].each do |json_issue|
          issues.push(Jira::Issue.new(json_issue))
        end

        puts "#{issues.size} / #{json["total"]} completed."
        puts ""

        break if index + MAX_SEARCH_RESULTS >= json["total"]
        index += MAX_SEARCH_RESULTS
      end
    end

    puts "issue num : #{issues.size} (#{benchmark_result.floor}s)"
    puts ""

    return issues
  end

  # TODO:
  # On the way of design.
  #
  # NOTE:
  # To edit StoryPoint via script, StoryPoint field needs to be shown in JIRA screen.
  # Go to 'JIRA Software' from left top icon.
  # 'JIRA Settings' => 'Screens' => 'Default Issue Screen' Edit => 'Field Tab'.
  # Add 'Story Points' field there.
  def self.update_issue(key, param_hash)
    payload = JSON.pretty_generate(param_hash).to_s

    ApiCallerRestClient.call("#{JIRA_URL}/issue/#{key}",
                             Credentials::UserName,
                             Credentials::Password,
                             :PUT,
                             payload)
  end
end
