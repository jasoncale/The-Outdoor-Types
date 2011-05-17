require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cache'
require 'haml'
require 'sass'
require 'lastfm'
require 'tumblr'
require 'bandcamp'
require 'yaml'
require 'active_support/time'

module Outdoortypes
  class Site < Sinatra::Base
    set :haml, :format => :html5
    set :root, File.dirname(__FILE__)

    get '/' do
      cache_for(20.minutes)
      @shows = Outdoortypes::Event.get
      @review = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:reviews]), :quote).sort_by { rand }.first
      @image = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:about]), :photo).sort_by { rand }.first
      @news = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:news], :num => 2)) || []
      @blog_url = "http://#{config[:tumblr][:news]}.tumblr.com"
      haml :index
    end
    
    get '/about' do
      cache_for(20.minutes)
      content = tumblr_content(config[:tumblr][:about])
      @title = content['tumblr']['tumblelog']['title']
      @image = Tumblr::Reader.get_posts(content, :photo).sort_by { rand }.first
      @about = Tumblr::Reader.get_posts(content, :regular).first
      @reviews = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:reviews]), :quote)      
      haml :about
    end
    
    get '/shows' do
      cache_for(20.minutes)
      @image = Tumblr::Reader.get_posts(tumblr_content(config[:tumblr][:shows]), :photo).sort_by { rand }.first
      @shows = Outdoortypes::Event.get
      haml :shows
    end
    
    get '/music' do
      cache_for(1.hour)
      @discography = band.discography.sort_by {|album| album['release_date'] }.reverse      
      haml :music
    end
    
    get '/music/:name' do
      cache_for(1.hour)
      @discography = band.discography.reject { |album| album['title'].downcase.gsub(/\s/, '-') == params[:name] }.sort_by {|album| album['release_date'] }.reverse
      @album = load_album(params[:name])
      if @album
        haml :album
      else
        not_found
      end
    end
    
    get '/contact' do
      cache_for(1.day)
      content = tumblr_content(config[:tumblr][:contact])
      @title = content['tumblr']['tumblelog']['title']
      @image = Tumblr::Reader.get_posts(content, :photo).sort_by { rand }.first
      @info = Tumblr::Reader.get_posts(content, :regular).first
      haml :contact
    end

    get '/style.css' do
      cache_for(1.hour)
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
    
    def cache_for(seconds)
      response.headers['Cache-Control'] = "0public, max-age=#{seconds.to_s}"
    end
  end
  
  class Base
    class << self
      def config
        @config ||= (
          if File.exists?(File.dirname(__FILE__) + "/config.yml")
            config_path = File.read(File.dirname(__FILE__) + "/config.yml")
            YAML.load(config_path)["config"]
          else
            {
              :lastfm => {
                :artist => ENV['LASTFM_ARTIST'],
                :api_key => ENV['LASTFM_KEY'],
                :api_secret => ENV['LASTFM_SECRET']
              },
              :tumblr => {
                :email => ENV['TUMBLR_EMAIL'],
                :password => ENV['TUMBLR_PASS'],
                :reviews => "odtreviews",
                :about => "odtabout",
                :news => "theoutdoortypes1",
                :shows => "odtshows",
                :contact => "odtcontact"
              },
              :bandcamp => {
                :api_key => ENV['BANDCAMP_KEY'],
                :band_id => ENV['BANDCAMP_BANDID']
              }
            }            
          end
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