# coding: utf-8

module Jira
  # TODO IssueType definition depends on the Site
  Types = [
    "Epic",
    "Story",
    "Sub-task",
    "Bug",
    "Spike",
    "Question",
  ]

  SimpleStatus = [
    "Done",
    "Not Done"
  ]

  class FixVersions
    attr_reader :id
    attr_reader :name
    attr_reader :release_date

    def initialize(version_hash)
      @id           = version_hash["id"]
      @name         = version_hash["name"]
      @release_date = version_hash["releaseDate"]
    end

    def <=>(other)
      self.name <=> other.name
    end
  end

  class Sprint
    require 'Date'

    attr_reader :name

    # Jira returns sprint as following
    # com.atlassian.greenhopper.service.sprint.Sprint@4cd19e2e[id=14424,rapidViewId=844,state=CLOSED,name=Sprint 34.1 (03/12-03/25),startDate=2020-03-13T05:53:56.618Z,endDate=2020-03-26T00:37:00.000Z,completeDate=2020-03-27T03:56:46.496Z,sequence=14424,goal=]
    def initialize(sprint_string)
      sprint_string.match(/\[(.*?)\]/) do |match|
        params = match[0]

        @id        = params[/id=(.*?),/,        1]
        @state     = params[/state=(.*?),/,     1]
        @name      = params[/name=(.*?),/,      1]
        @startDate = params[/startDate=(.*?),/, 1]
        @endDate   = params[/endDate=(.*?),/,   1]

        @startDate = nil if (@startDate == "<null>") # JIRA format
        @endDate   = nil if (@endDate   == "<null>") # JIRA format

        @startDate = Date.parse(@startDate) if @startDate
        @endDate   = Date.parse(@endDate)   if @endDate
      end

      abort if (@id.nil? || @state.nil? || @name.nil?)
    end

    def <=>(other)
      self.name <=> other.name # TODO is it okay to compare by name ?
    end
  end

  class Issue
    attr_reader :key
    attr_reader :title              # summary
    attr_reader :parent_key         # parent > key
    attr_reader :subtask_keys       # subtasks > key
    attr_reader :assignee           # assignee > displayName
    attr_reader :type               # issuetype > name
    attr_reader :timeTracking
    attr_reader :story_points
    attr_reader :original_estimate  # (sec)
    attr_reader :remaining_estimate # (sec)
    attr_reader :time_spent         # (sec)
    attr_reader :status             # status > name
    attr_reader :sprints
    attr_reader :project
    attr_reader :components
    attr_reader :description
    attr_reader :versions
    attr_reader :labels
    attr_reader :epic
    attr_reader :priority

    def initialize(json)
      @key = json["key"]

      fields = json["fields"]
      @title              = fields["summary"]
      @parent_key         = fields["parent"]["key"] if fields["parent"]
      @subtask_keys       = get_subtask_keys(fields["subtasks"])
      @assignee           = fields["assignee"]["displayName"] if fields["assignee"] # "name" "emailAddress" are also available
      @type               = fields["issuetype"]["name"]
      @original_estimate  = fields["timeoriginalestimate"]
      @remaining_estimate = fields["timeestimate"]
      @time_spent         = fields["timespent"]
      @status             = fields["status"]["name"]
      @project            = fields["project"]["key"]
      @components         = fields["components"]
      @description        = fields["description"]
      @versions           = get_fixVersions(fields["fixVersions"])
      @labels             = fields["labels"]
      @priority           = fields["priority"]["id"]

      # TODO followings Depends on the Site
      @story_points       = fields["customfield_10024"]
      @sprints            = get_sprints(fields["customfield_10020"])
      @epic               = fields["customfield_10014"]
    end

    def inspect
      "[#{@key}] #{@title} - #{@epic} (#{@story_points})"
    end

    def get_subtask_keys(json)
      json.map { |subtask_json| subtask_json["key"] }
    end

    # Sprints are available as the Array of Strings. See Sprint::initalize()
    def get_sprints(sprint_strings)
      return [] if sprint_strings.nil?
      sprint_strings.map { |sprint_string| Sprint.new(sprint_string) }
    end

    def sprint
      return nil if @sprints.empty?
      return @sprints.last
    end

    def get_fixVersions(version_hashes)
      # TODO 'sort' is workaround for handling multiple versions.
      # Currently only the array-top version is handled in this script.
      version_hashes.map { |version_hash| FixVersions.new(version_hash) }.sort!
    end

    def story?
      @type == 'Story'
    end

    def subtask?
      @type == 'Sub-task'
    end

    def bug?
      @type == 'Bug'
    end

    def question?
      @type == 'Question'
    end

    # TODO status definition depends on the Site
    def done?
      case (@type)
      when "Epic"
        @status == "Done"
      when "Story"
        @status == "Done"
      when "Sub-task"
        @status == "Done"
      when "Bug"
        @status == "Done"
      when "Spike"
        @status == "Done"
      when "Question"
        @status == "Done"
      else
        abort "unexpected type #{@type} status: #{@status}"
      end
    end

    def done_at_(complete_sprint_name)
      return false unless done?
      return (sprint && sprint.name == complete_sprint_name)
    end

    def has_subtasks?
      !subtask_keys.empty?
    end

    def select_subtasks_from_(issues)
      abort "must be array" unless issues.class == Array

      subtasks = Array.new
      issues.each do |issue|
        subtasks << issue if subtask_keys.include? (issue.key)
      end

      return subtasks
    end

    # TODO on the way of function design
    def self.compose_hash(story_point:)
      param = Hash.new
      param[:fields] = Hash.new
      param[:fields][:customfield_10024] = story_point.to_f if story_point # TODO customfield depends on your Site.

      return param
    end
  end
end


class Array
  def filter_by_type!(type)
    self.select! { |issue| issue.type == type }
  end

  def exclude_by_type!(type)
    self.reject! { |issue| issue.type == type }
  end

  def filter_by_simple_status!(status)
    case (status)
    when "Done"
      filter_done!
    when "Not Done"
      return filter_undone!
    else
      abort "invalid type #{type}"
    end
  end

  def filter_done!
    self.select! { |issue| issue.done? }
  end

  def filter_undone!
    self.reject! { |issue| issue.done? }
  end

  def compare_nullables(objL, objR)
    if objL && objR
      objL <=> objR
    else
      objR ? 1 : -1 # -1:left, 1:right. If both are nil then return left.
    end
  end

  def sort_by!(type)
    self.sort! do |issueL, issueR|
      case type
      when :key
        issueL.key <=> issueR.key
      when :assignee
        compare_nullables(issueL.assignee, issueR.assignee)
      when :status
        issueL.status <=> issueR.status
      when :epic
        compare_nullables(issueL.epic, issueR.epic)
      when :version
        compare_nullables(issueL.versions[0], issueR.versions[0])
      when :sprint
        compare_nullables(issueL.sprint, issueR.sprint)
      else
        abort "unknown #{:what}"
      end
    end
  end

  def epic_keys
    self.map { |issue| issue.epic }.uniq.compact
  end

  def select_issues_which_(type, value)
    case type
    when :epic
      abort "value must be Epic Issue #{value}" unless value.is_a? Jira::Issue
      self.select { |issue| issue.epic == value.key }
    when :sprint_name
      if value.nil?             # Equals to Backlog
        self.select { |issue| issue.sprint.nil? }
      else
        self.select { |issue| issue.sprint && issue.sprint.name == value }
      end
    when :key
      if value.is_a? Array
        self.select { |issue| value.include? issue.key }
      else
        self.select { |issue| issue.key == value }
      end
    else
      abort "unknown type #{type}"
    end
  end
end
