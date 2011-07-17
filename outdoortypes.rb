require 'sinatra/base'
require 'sinatra/reloader'
require 'haml'
require 'sass'
require 'lastfm'
require 'tumblr'
require 'bandcamp'
require 'yaml'
require 'active_support/time'
require 'active_support/core_ext/string/filters'
require 'webmock'

module Outdoortypes
  class Site < Sinatra::Base
    set :haml, :format => :html5
    set :root, File.dirname(__FILE__)

    include WebMock::API
    WebMock.allow_net_connect!

    get '/' do
      cache_for(20.minutes)
      @shows = Outdoortypes::Event.get
      @review = random_post :reviews, :quote
      @image = random_image :about
      @news = latest_post :news, :regular
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
      cache_for(1.day)
      @discography = discography
      haml :music
    end

    get '/music/:name' do
      cache_for(1.day)
      @discography = discography.select { |album| album['title'].downcase.gsub(/\s/, '-') != params[:name] }
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

    # HELPERS

    helpers do
      def link_to_unless_current(label, link, title = nil)
        title = "Go to #{label} page" if title.nil?
        klassy = " class='current'" if request.path_info == link
        link_html = "<a href='#{link}' title='#{title}'#{klassy}>#{label}</a>"
        link_html
      end
    end

    def tumblr_content(name, opts = {})
      Outdoortypes::TumblrBlog.get(name, opts)
    end

    def discography
      stub_json_request("http://api.bandcamp.com/api/band/3/discography?band_id=#{config[:bandcamp][:band_id]}&key=#{config[:bandcamp][:api_key]}", "discography")
      Bandcamp::Base.api_key = config[:bandcamp][:api_key]
      return Bandcamp::Band.new({ "band_id" => config[:bandcamp][:band_id] }).discography.sort_by {|album| album['release_date'] }.reverse
    end

    def load_album(name)
      if album = discography.select {|album| album['title'].downcase.gsub(/\s/, '-') == name }.first
        if stub_exists?("album-#{album['album_id']}")
          stub_json_request("http://api.bandcamp.com/api/album/2/info?album_id=#{album['album_id']}&key=#{config[:bandcamp][:api_key]}", "album-#{album['album_id']}")
        end
        album = Bandcamp::Album.load(album['album_id'])
      end
    end

    def config
      Outdoortypes::Base.config
    end

    def cache_for(seconds)
      response.headers['Cache-Control'] = "public, max-age=#{seconds.to_s}"
    end

    def stub_json_request(url, json_file)
      stub_request(:get, url).to_return(
        {
          :body => File.read(stub_file_path(json_file)),
          :headers => { "Content-Type" => "text/json" }
        }
      )
    end

    def stub_exists?(json_file)
      File.exists?(stub_file_path(json_file))
    end

    def stub_file_path(json_file)
      File.dirname(__FILE__) + "/json-cache/#{json_file}.json"
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
                :news => "theoutdoortypes",
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