# Notify the yammer feed when something is deployed
# Add twitter, friendfeed, etc someday maybe
#
#
begin
  require 'rubygems'
  require 'yammer4r'
rescue LoadError
  "In order to use the yammer notifier the yammer4r gem must first be installed. " +
    "type: sudo gem install --source http://gems.github.com jstewart-yammer4r"
end


class Notifier
  def self.say(msg)
    config_path = File.dirname(__FILE__) + '/config/oauth.yml'
    y = Yammer::Client.new(:config => config_path) 
    y.message(:post, :body => msg)
  end
end
