#!/usr/bin/env ruby

require 'uri'
require 'open-uri'
require 'rubygems'
require 'json'
require 'active_support'


class TwitterGrowl
  @@url = 'http://twitter.com/statuses/friends_timeline.json'
  @@config = File.dirname(__FILE__) + '/config.yml'
  @@cache_path = File.dirname(__FILE__) + '/cache/'

  def initialize
    @config = YAML.load_file(@@config)
    Dir.mkdir(@@cache_path)  unless File.exist?(@@cache_path)
  end

  # TODO use since= param
  def url
    if since = @config[:last_created_at]
      @@url + '?since=' + URI.encode(since)
    else
      @@url
    end
  end

  def image(url)
    returning(@@cache_path + url.gsub(/[\W]+/, '_')) do |file|
      open(file, 'w') do |f|
        open(url) do |h|
          f.write(h.read)
        end
      end  unless File.exists?(file)
    end
  end

  def user(user_id)
    file = "#{@@cache_path}#{user_id}.json"
    unless File.exists?(file) && !File.zero?(file)
      open(file, 'w') do |f|
        request("http://twitter.com/users/show/#{user_id}.json") do |u|
          f.write(u.read)
        end
      end
    end

    open(file) do |f| JSON.parse(f.read) end
  end

  def growl(tweet)
    #puts tweet['text']
    options = "--image #{image(tweet['user']['profile_image_url'])}"
    options += " --sticky"  if sticky?(tweet)
    open("|growlnotify #{options} #{tweet['user']['screen_name']} 2>/dev/null", 'w') do |g|
      g.write(tweet['text'])
    end
  end

  def sticky?(tweet)
    keywords = @config[:sticky] || []
    keywords.any? { |k| tweet['text'].include?(k) } ||
      user(tweet['user']['id'])['notifications']
  end

  def run
    tweets =
      request(@@url) do |f|
        JSON.parse(f.read)
      end

    last_created_at = Time.parse(@config[:last_created_at] || tweets.last['created_at'])

    tweets.each do |t|
      created_at = Time.parse(t['created_at'])
      break  if created_at <= last_created_at
      next   if t['user']['screen_name'] == @config[:user]

      growl(t)
    end

    @config[:last_created_at] = tweets.first['created_at']
    File.open(@@config, 'w') do |f| f.write(YAML.dump(@config)) end
  end

  private
    def request(url)
      user, password = @config.values_at(:user, :password)
      open(url, :http_basic_authentication => [ user, password ]) do |u|
        yield(u)
      end
    end
end

TwitterGrowl.new.run  if $0 == __FILE__
