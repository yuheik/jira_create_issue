require 'rest-client'
require 'json'
require 'benchmark'

class ApiCallerRestClient
  SHOW_BENCHMARK = false

  def self.call(url, id, password, method, payload)
    response = nil
    benchmark_result = Benchmark.realtime do
      begin
        response = RestClient::Request.new(:method     => method,
                                           :url        => url,
                                           :user       => id,
                                           :password   => password,
                                           :proxy      => nil,
                                           :verify_ssl => false,
                                           :payload    => payload,
                                           :headers    => {
                                             :content_type => "application/json;charset=UTF-8"
                                           }
                                          ).execute
      rescue RestClient::ExceptionWithResponse => e
        puts "Error: (#{e.message} with #{e.response})"
        puts "Failed: #{e.backtrace}"
        abort
      end
    end

    puts "call done (#{benchmark_result.floor}s)" if SHOW_BENCHMARK
    puts ""                                       if SHOW_BENCHMARK

    # dump(response)
    return response.body
  end

  def self.dump(response)
    abort if response.class != RestClient::Response

    puts "Dump Response --"
    puts "code:       #{response.code}"
    puts "body:       #{response.body}"
    puts "headers:    #{JSON.pretty_generate(response.headers)}"
    puts "cookies:    #{JSON.pretty_generate(response.cookies)}"
    puts "cookie_jar: #{response.cookie_jar.inspect}"
    puts "request:    #{response.request.inspect}"
    puts "history:    #{response.history}"
  end
end
