#! /usr/bin/env ruby
# coding: utf-8

require_relative './lib/jira/jira'
require_relative './lib/jira/jira_api_caller'
require 'csv'

begin
  csv_file = ARGV[0]
  abort "error. file must be csv: #{csv_file}" unless (csv_file &&
                                                       File.exist?(csv_file) &&
                                                       File.extname(csv_file) == '.csv')

  # read csv
  csv_data = CSV.read(csv_file, headers: true, encoding: 'UTF-8', skip_blanks: true)

  csv_data.each_with_index do |row, index|
    if (row["skipthis"])
      puts sprintf("line %3d : skipped    > %s",
                   index+2, # index + 1 (each_with_index starts from 0) + 1 (csv's title line)
                   row["summary"])
      next
    end

    hash = Jira::Issue.create_hash(:project     => row["project"],
                                   :type        => row["type"],
                                   :parent      => row["parent"],
                                   :title       => row["title"],
                                   :description => row["description"],
                                   :labels      => row["labels"],
                                   :assignee    => row["assignee"],
                                   :estimate    => row["estimate"],
                                   :versions    => row["versions"],
                                   :severity    => row["severity"],
                                   # milestone
                                   :storypoint  => row["storypoint"],
                                   :epic        => row["epic"],
                                   :components  => row["components"],
                                   :priority    => row["priority"])
    JiraApiCaller.create_issue(hash)

    puts sprintf("line %3d : Registered > %s",
                 index+2, # index + 1 (each_with_index starts from 0) + 1 (csv's title line)
                 row["title"])
  end
end
