#!/usr/bin/env ruby
require "rubygems"
require "bundler"
Bundler.setup

$LOAD_PATH << File.dirname(__FILE__) + "/lib"

require "sinatra"

enable :logging, :dump_errors, :raise_errors

environment = ENV["RACK_ENV"]

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/#{environment}.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

require 'outdoortypes'
run Outdoortypes::Site