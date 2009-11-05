$:.unshift(File.dirname(__FILE__))
require 'json/json'
require 'oauth/oauth'
require 'yammer4r/yammer4r'


class Notifier
  def self.say(msg)
    default_config  = "/etc/oauth_yammer.yml"
    local_config    = File.dirname(__FILE__) + '/../config/oauth.yml'
    config_path     = File.exist?(local_config) ? local_config : default_config
    y = Yammer::Client.new(:config => config_path)
    y.message(:post, :body => msg)
  end
end
