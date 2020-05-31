#! /usr/bin/env ruby
# coding: utf-8

require 'net/https'
require 'uri'
require 'benchmark'

class ApiCaller
  def self.call(url, id, password, silent = false)
    puts "calling: #{url}" unless silent

    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req.basic_auth(id, password)

    response = nil
    benchmark_result = Benchmark.realtime do
      response = Net::HTTP.start(uri.host,
                                 uri.port,
                                 :use_ssl => (uri.scheme == 'https')) do |http|
        http.request(req)
      end
    end

    puts "call done. (#{benchmark_result.floor}s)" unless silent
    puts ""                                        unless silent

    unless response.is_a? Net::HTTPSuccess
      puts "failed:"
      abort response.body
    end

    return response.body
  end
end
