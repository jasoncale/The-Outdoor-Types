require 'sinatra/base'
require 'sinatra/reloader'
require 'haml'
require 'sass'
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
      @image = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:about], :num => 2), :photo).sort_by { rand }.first
      @news = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:news], :num => 2)) || []
      @blog_url = "http://#{config[:tumblr][:news]}.tumblr.com"
      haml :index
    end
    
    get '/about' do
      content = tumblr_content(config[:tumblr][:about], :num => 2)
      @title = content['tumblr']['tumblelog']['title']
      @image = Tumblr::Reader.get_posts(content, :photo).sort_by { rand }.first
      @body = Tumblr::Reader.get_posts(content, :regular).first
      haml :about
    end
    
    get '/shows' do
      @shows = Outdoortypes::Event.get
      haml :shows
    end
    
    get '/press' do
      content = tumblr_content(config[:tumblr][:reviews])
      @title = content['tumblr']['tumblelog']['title']
      @reviews = Tumblr::Reader.get_posts(content, :quote)
      haml :press
    end
    
    get '/music' do
      @discography = band.discography.sort_by {|album| album['release_date'] }.reverse      
      haml :music
    end
    
    get '/music/:name' do
      @album = load_album(params[:name])
      if @album
        haml :album
      else
        not_found
      end
    end

    get '/style.css' do
      scss :stylesheet
    end
    
    def tumblr_content(name, opts = {})
      Outdoortypes::TumblrBlog.get(name, opts)
    end
    
    def band
      Bandcamp::Base.api_key = config[:bandcamp][:api_key]  
      @band = Bandcamp::Band.load(config[:bandcamp][:band_id])
    end
    
    def load_album(name)
      if band && band.discography && album = band.discography.select {|album| album['title'].downcase.gsub(/\s/, '-') == name }.first
        album = Bandcamp::Album.load(album['album_id'])
      end
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