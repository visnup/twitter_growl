#!/usr/bin/env ruby

require 'open-uri'
require 'rubygems'
require 'json'
require 'active_support'


class TwitterGrowl
  @@url = 'http://twitter.com/statuses/friends_timeline.json'
  @@config = File.dirname(__FILE__) + '/config.yml'
  @@image_path = File.dirname(__FILE__) + '/images/'

  def initialize
    @config = YAML.load_file(@@config)
    Dir.mkdir(@@image_path)  unless File.exist?(@@image_path)
  end

  def image(url)
    returning(@@image_path + url.gsub(/[\W]+/, '_')) do |file|
      open(file, 'w') do |f|
        open(url) do |h|
          f.write(h.read)
        end
      end  unless File.exists?(file)
    end
  end

  def growl(tweet)
    options = "--image #{image(tweet['user']['profile_image_url'])} --sticky"
    open("|growlnotify #{options} #{tweet['user']['screen_name']}", 'w') do |g|
      g.write(tweet['text'])
    end
  end

  def run
    user, password = @config.values_at(:user, :password)

    tweets =
      open(@@url, :http_basic_authentication => [ user, password ]) do |f|
        JSON.parse(f.read)
      end

    last_created_at = Time.parse(@config[:last_created_at] || tweets.last['created_at'])

    tweets.each do |t|
      created_at = Time.parse(t['created_at'])
      break  if created_at <= last_created_at

      growl(t)
    end

    @config[:last_created_at] = tweets.first['created_at']
    File.open(@@config, 'w') do |f| f.write(YAML.dump(@config)) end
  end
end

TwitterGrowl.new.run
