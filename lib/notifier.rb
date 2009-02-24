require 'json/json'
require 'oauth/oauth'
require 'yammer4r/yammer4r'


class Notifier
  def self.say(msg)
    config_path = File.dirname(__FILE__) + '/../config/oauth.yml'
    y = Yammer::Client.new(:config => config_path) 
    y.message(:post, :body => msg)
  end
end
