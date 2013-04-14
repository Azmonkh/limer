# -*- encoding: utf-8 -*-
require 'rubygems'
require 'highline'
require 'pivotal-tracker'
require 'yaml'

module Limer
  class Gitpt
    attr_reader :token, :highline, :initials, :name, :memberships, :applicable_stories, :setting_file

    def initialize
      @highline = HighLine.new
      @setting_file = File.join(ENV['HOME'], '.gitpt')

      load_setting
      hello unless settings_valid?
      request_settings while not settings_valid?
      stored if not settings_valid?
      PivotalTracker::Client.use_ssl = true
      PivotalTracker::Client.token = token
    end

    def highlight string
      bold HighLine::BLUE + string
    end

    def bold string
      HighLine::BOLD + string + HighLine::RESET
    end

    def hello
      highline.say HighLine::RESET
      highline.say "Welcome to #{bold 'gitpt'}.\n\n"
    end

    def settings_valid?
      token and token.size > 0
    end

    def stored
      highline.say "
        Thank you. Your settings have been stored at #{highlight @settings_file}
        You may remove that file for the wizard to reappear.

        ----------------------------------------------------"

    end

    def load_setting
      if File.exists? setting_file
        settings = YAML.load(File.read setting_file)
        @initials = settings[:initials]
        @token = settings[:token]
      else
      end
    end

    def load_project
      project_id_file = '.pt_project_id'
      if File.exists? project_id_file
        project_ids = File.read(project_id_file).split(/[\s]+/).map(&:to_i)
      end
      unless project_ids and project_ids.size > 0
        highline.say "No project config provided. Add project id(s) to .pt_project_id file"
        exit 1
      end
      loading 'Connecting to Pivotal Tracker: ... ' do
        projects = project_ids.collect do |project_id|
          PivotalTracker::Project.find(project_id)
        end

        @memberships = projects.collect(&:memberships).map(&:all).flatten

        @applicable_stories = projects.collect do |project|
          project.stories.all(:state => 'started,finished,rejected')
        end.flatten
      end
    end

    def loading(message, &block)
      print message
      STDOUT.flush
      yield
      print "\r" + ' ' * message.size + "\r" # Remove loading message
      STDOUT.flush
    end

    def request_settings
      highline.say highlight('Your settings are missing or invalid.')
      highline.say "Please configure your Pivotal Tracker access.\n\n"
      token = highline.ask bold("Your API key:") + " "
      initials = highline.ask bold("Your PT initials") + " (optional, used for highlighting your stories): "
      highline.say "\n"

      settings = { :token => token, :initials => initials }

      File.open setting_file, 'w' do |file|
        file.write settings.to_yaml
      end

      load_setting
    end

    def choose_story
      selected_story = nil

      highline.choose do |menu|
        menu.header = "Choose a story"
        applicable_stories.each do |story|
          owner_name = story.owned_by
          owner = if owner_name
            owners = memberships.select{|member| member.name == owner_name}
            owners.first ? owners.first.initials : '?'
          else 
            '?'
          end

          state = story.current_state
          if state == 'started'
            state = HighLine::GREEN + state + HighLine::RESET
          elsif state != 'finished'
            state = HighLine::RED + state + HighLine::RESET
          end
          state += HighLine::BOLD if owner == initials

          label = "(#{owner}, #{state}) #{story.name}"
          label = bold(label) if owner == initials
          menu.choice(label) { selected_story = story }
        end
        menu.hidden ''
      end

      if selected_story
        message = highline.ask("\nAdd an optional message")
        highline.say message

        commit_message = "[##{selected_story.id}] #{selected_story.name}"
        if message.strip != ''
          commit_message << ' - '<< message.strip
        end

        puts commit_message
        # exec('git', 'commit', '-m', commit_message)
      end
    end
    def run
      load_project
      choose_story
    end
  end
end
