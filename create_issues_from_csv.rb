#! /usr/bin/env ruby
# coding: utf-8

require 'csv'
require 'rest-client'
require 'json'
require 'io/console'
require 'logger'
require 'date'
require './my_credential'

# If set to 'true' actual JIRA operation won't run.
# Attention: Default is 'false'.
$dryrun = false

#global variables
$url_jira_api = "#{Site}/rest/api/2/"

#Global ID Info.
$username_jira = UserName
$password_jira = Password


class JiraIssue
  def initialize(key)
    proc_hash = Proc.new { |h, k| h[k] = Hash.new &proc_hash; }
    @jira_issue = Hash.new &proc_hash
    @key = key if !key.nil?
  end

  def setProject(project)
    if project != nil
      @jira_issue[:fields][:project][:key] = project
    end
  end

  def setIssueType(type)
    if type != nil
      @jira_issue[:fields][:issuetype][:name] = type
    end
  end

  def setTaskType(tasktype)
    if tasktype != nil
      @jira_issue[:fields][:customfield_15040][:value] = tasktype
    end
  end

  def setSummary(summary)
    if summary != nil
      @jira_issue[:fields][:summary] = summary
    end
  end

  def setComponents(components)
    if components != nil
      array = [];
      components_array = components.split(",")
      components_array.each { |component| array.push({"name" => component}) }
      @jira_issue[:fields][:components] = array
    end
  end

  def setDescription(description)
    if description != nil
      @jira_issue[:fields][:description] = description
    end
  end

  def setVersions(versions)
    if versions != nil
      array = [];
      versions.split(",").each do |version|
        array.push({"name" => version.strip!})
      end
      @jira_issue[:fields][:fixVersions] = array
    end
  end

  def setLabels(labels)
    if labels != nil
      @jira_issue[:fields][:labels] = labels.split(",")
    end
  end

  def setAssignee(adname)
    if adname != nil
      @jira_issue[:fields][:assignee][:name] = adname
    end
  end

  def setSeverity(severity)
    if severity != nil
      @jira_issue[:fields][:customfield_10004][:value] = severity
    end
  end

  def setMilestones(milestone)
    if milestone != nil
      @jira_issue[:fields][:customfield_14160][:value] = milestone
    end
  end

  def setParent(parent)
    if parent != nil
      @jira_issue[:fields][:parent][:key] = parent
    end
  end

  def setEpic(epic)
    if epic != nil
      # Extract key if full path is given. (ex. http://xxx.jira.com/EPIC-XXX => EPIC-XXX)
      epic.gsub!(/http.*\//, "") if (epic =~ /http.*/)
      @jira_issue[:fields][:customfield_10940] = epic
    end
  end

  def setStorypoint(point)
    if point != nil
      @jira_issue[:fields][:customfield_10142] = point.to_f
    end
  end

  def setEpicName(epicName)
    if epicName != nil
      @jira_issue[:fields][:customfield_10941] = epicName
    end
  end

  def setProgramEpic(programEpic)
    if programEpic != nil
      @jira_issue[:fields][:customfield_14463] = programEpic
    end
  end

  def setPdM(pdm)
    if pdm != nil
      @jira_issue[:fields][:customfield_14163][:name] = pdm
    end
  end

  def setDevLead(devlead)
    if devlead != nil
      @jira_issue[:fields][:customfield_14161][:name] = devlead
    end
  end

  def setPriority(priority)
    if priority != nil
      @jira_issue[:fields][:customfield_15470][:value] = priority
    end
  end

  def setEstimate(estimate)
    if estimate != nil
      @jira_issue[:fields][:timetracking][:originalEstimate] = estimate

      #@jira_issue[:fields][:timetracking][:remainingEstimate] = estimate
      #Time tracking must be enabled to set these fields. In addition, if you are using the JIRA "Legacy" time tracking mode
      #(set by a JIRA Administrator), then only the remaining estimate can be set, so the "originalestimate" field should not
      #be included in the REST request.
    end
  end

  def create()
    json_in = JSON.pretty_generate(@jira_issue);

    begin
      response = RestClient::Request.new(
        :method => :POST,
        :url => "#{$url_jira_api}issue",
        :user => $username_jira,
        :password => $password_jira,
        :proxy => nil, # Depending on your environment
        :verify_ssl => false, #OpenSSL::SSL::VERIFY_PEER
        :payload => json_in.to_s,
        :headers => { :content_type => "application/json;charset=UTF-8" }
      ).execute
    rescue RestClient::ExceptionWithResponse => e
      print "\tError: (#{e.message} with #{e.response})\n"
      print "\tCreation failed: #{e}\n\t#{e.backtrace}\n"
      exit!
    else
      json_out = JSON.parse(response.to_str)
      # Ex) {"id"=>"425862", "key"=>"PPRSYS-4", "self"=>"https://jira.sie.sony.com/rest/api/2/issue/425862"}
      return json_out['key']
    end
  end
end

def is_blank?(data)
  case data["issueType"]
  when "Sub-task"
    (data["summary"] == nil &&
     data["assignee"] == "#N/A" &&
     data["parent"] == nil)
  else
    (data["summary"] == nil)
  end
end

begin
  if ARGV.empty?
    #FullPath of csv file
    #Cannot include spaces
    #UTF-8 encoded files only
    puts 'Input full path of the csv file'
    csv_file = gets.chomp!
  else
    csv_file = ARGV[0]
    abort "file must be csv: #{csv_file}" unless (csv_file &&
                                                  File.exist?(csv_file) &&
                                                  File.extname(csv_file) == '.csv')
  end

  # read csv
  csv_data = CSV.read(csv_file, headers: true, encoding: 'UTF-8')


  data_num = csv_data.size
  #Loop by row in csv with following actions per row
  #1.new JiraIssue
  #2.set Datas
  #3.create issue
  csv_data.each_with_index do |data, index|
    if is_blank?(data)
      puts sprintf("line %3d : %s",
                   index+2, # index + 1 (each_with_index starts from 0) + 1 (csv's title line)
                   "empty line")
      next
    end

    if (data["skipthis"])
      puts sprintf("line %3d : skipped    > %-10s %s",
                   index+2, # index + 1 (each_with_index starts from 0) + 1 (csv's title line)
                   "",      # Key is blank
                   data["summary"])
      next
    end

    jiraIssue = JiraIssue.new(nil)
    jiraIssue.setProject(data["project"])
    jiraIssue.setIssueType(data["issuetype"])
    jiraIssue.setLabels(data["labels"])
    jiraIssue.setAssignee(data["assignee"])
    jiraIssue.setSummary(data["summary"])
    jiraIssue.setSeverity(data["severity"])
    jiraIssue.setComponents(data["components"])
    jiraIssue.setDescription(data["description"])
    jiraIssue.setVersions(data["versions"])
    jiraIssue.setMilestones(data["milestone"])
    jiraIssue.setParent(data["parent"])
    jiraIssue.setEpic(data["epic"])
    jiraIssue.setStorypoint(data["storypoint"])
    jiraIssue.setEstimate(data["estimate"])
    jiraIssue.setTaskType(data["tasktype"])
    jiraIssue.setEpicName(data["EpicName"])
    jiraIssue.setProgramEpic(data["ProgramEpic"])
    jiraIssue.setPdM(data["PdM"])
    jiraIssue.setDevLead(data["DevLead"])
    jiraIssue.setPriority(data["Priority"])

    # create
    if ($dryrun)
      key = "dryrun"
    else
      key = jiraIssue.create()
    end
    puts sprintf("line %3d : Registered > %-10s %s",
                 index+2, # index + 1 (each_with_index starts from 0) + 1 (csv's title line)
                 key,
                 data["summary"]
                )
  end
end
