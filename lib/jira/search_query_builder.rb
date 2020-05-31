#! /usr/bin/env ruby

module JiraApi
  class SearchQueryBuilder
    #
    # @param params[:project]      Project name. Mandatory.
    # @param params[:sprint]       'Sprint name' or 'active' or nil
    # @param params[:filter_type]  issue type which will be filtered or nil
    # @param params[:exclude_type] issue type which will be excluded or nil
    # @param params[:epiclink]     issues which epic link would be
    #
    def self.build_query(params)
      abort "params is not Hash" if params.class != Hash
      abort "project is missing" if params[:project].nil?

      jql = "project = #{params[:project]} "

      if params[:sprint]
        if params[:sprint] == 'active'
          jql += "AND sprint in openSprints() "
        else
          jql += "AND sprint = \"#{params[:sprint]}\" "
        end
      end

      jql += "AND type = \"#{params[:filter_type]}\" "                 if params[:filter_type]
      jql += "AND type != \"#{params[:exclude_type]}\" "               if params[:exclude_type]
      jql += "AND assignee = \"#{params[:assignee]}\" "                if params[:assignee]
      jql += "AND \"Epic Link\" in (#{params[:epiclink].join(', ')}) " if params[:epiclink]
      jql += "ORDER BY Rank "

      return jql
    end
  end
end
