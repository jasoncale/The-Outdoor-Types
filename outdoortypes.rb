require 'sinatra/base'
require 'sinatra/reloader'
require 'haml'
require 'less'
require 'lastfm'
require 'tumblr'
require 'bandcamp'
require 'yaml'


module Outdoortypes
  class Site < Sinatra::Base
    set :haml, :format => :html5
    
    get '/' do
      @shows = Outdoortypes::Event.get
      @review = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:reviews]), :quote).sort_by { rand }.first
      haml :index
    end
    
    get '/about' do
      content = tumblr_content(config[:tumblr][:about], :num => 2)
      @title = content['tumblr']['tumblelog']['title']
      @image = Tumblr::Reader.get_posts(content, :photo).first
      @body = Tumblr::Reader.get_posts(content, :regular).first
      haml :about
    end
    
    get '/shows' do
      @shows = Outdoortypes::Event.get
      haml :shows
    end
    
    get '/reviews' do
      content = tumblr_content(config[:tumblr][:reviews])
      @title = content['tumblr']['tumblelog']['title']
      @reviews = Tumblr::Reader.get_posts(content, :quote)
      haml :reviews
    end

    get '/style.css' do
      less :stylesheet
    end
    
    def tumblr_content(name, opts = {})
      @tumblr_content ||= Outdoortypes::TumblrBlog.get(name, opts)
    end
    
    def config
      Outdoortypes::Base.config
    end
  end
  
  class Base
    class << self
      def config
        @config ||= (
          config_path = File.read(File.dirname(__FILE__) + "/config.yml")
          YAML.load(config_path)["config"]
        )
      end
    end
  end
  
  class Event < Base    
    def self.api
      @api ||= Lastfm.new(config[:lastfm][:api_key], config[:lastfm][:api_secret])
    end
    
    def self.get
      api.artist.get_events(config[:lastfm][:artist])
    end
  end
  
  class TumblrBlog < Base
    def self.get(tumblr_blog, opts = {})
      opts = {:num => 10, :start => 0}.merge(opts)
      response = Tumblr::Reader.new(config[:tumblr][:email], config[:tumblr][:password]).authenticated_read(tumblr_blog, opts).perform        
    end
  end
end