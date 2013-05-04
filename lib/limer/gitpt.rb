# -*- encoding: utf-8 -*-
require 'rubygems'
require 'highline'
require 'pivotal-tracker'
require 'yaml'

module Limer
  class Gitpt
    attr_reader :token, :highline, :name, :memberships, :applicable_stories, :setting_file

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

    def missing string
      bold HighLine::RED + string
    end

    def bold string
      HighLine::BOLD + string + HighLine::RESET
    end

    def hello
      @highline.say HighLine::RESET
      @highline.say "Welcome to #{bold 'Limer'}.\n\n"
    end

    def settings_valid?
      token and token.size > 0
    end

    def stored
      @highline.say "
        Thank you. Your settings have been stored at #{highlight @settings_file}
        You may remove that file for the wizard to reappear.

        ----------------------------------------------------"
    end

    def load_setting
      if File.exists? setting_file
        settings = YAML.load(File.read setting_file)
        @name= settings[:name]
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
        @highline.say "Project id олдсонгүй." + bold(".pt_project_id") + " файлд хадгалана уу"
        exit 1
      end
      loading 'Pivotal Tracker холболт хийгдэж байна: ... ' do
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
      @highline.say missing('Тохиргооны файл байхгүй байна.')
      @highline.say "Pivotal Tracker холбогдох тохиргоог хийнэ үү.\n\n"
      @token = @highline.ask bold("API key: ")
      @name= @highline.ask bold("Pivotal Tracker дээрх нэр: ")
      @highline.say "\n"

      settings = { :token => @token, :name=> @name}

      File.open setting_file, 'w' do |file|
        file.write settings.to_yaml
      end

      load_setting
    end

    def choose_story
      selected_story = nil

      @highline.choose do |menu|
        menu.header = HighLine::BLUE + "Story сонгоно уу" + HighLine::RESET
        @applicable_stories.each do |story|
          owner_name = story.owned_by
          owner = if owner_name
            owners = memberships.select{|member| member.name == owner_name}
            owners.first ? owners.first.name: '?'
          else 
            '?'
          end

          state = story.current_state
          if state == 'started'
            state = HighLine::GREEN + state + HighLine::RESET
          elsif state != 'finished'
            state = HighLine::RED + state + HighLine::RESET
          end
          state += HighLine::BOLD if owner == @name

          label = "(" + HighLine::YELLOW + "#{owner}"+ HighLine::RESET + ", #{state}) #{story.name} - " + HighLine::BLUE + story.story_type.capitalize + HighLine::RESET
          label = bold(label) if owner == @name
          menu.choice(label) { selected_story = story }
        end
        menu.choice 'Гарах' do |chosen|
          exit 1
        end
        menu.hidden ''
      end

      if selected_story
        message = nil
        @highline.choose do |menu|
          menu.header = "Төрлөө сонгоно уу"
          menu.choices "fixed","delivers","Гарах" do |chosen|
            if chosen == "Гарах"
              exit 1
            end
            message = chosen
          end
          menu.hidden ''
        end


        commit_message = "[#{message} ##{selected_story.id}] #{selected_story.name}"
        # puts commit_message
        exec('git', 'commit', '-m', commit_message)
      end
    end
    def run
      load_project
      choose_story
    end
  end
end
