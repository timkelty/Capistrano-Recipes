Capistrano::Configuration.instance.load do
  set(:ferret_conf)     { "#{shared_path}/config/ferret_server.yml" }
  set :has_ferret_server?, File.exist?('script/ferret_server')

  ferret_cmd = Proc.new do |op| 
    run_cmd = has_ferret_server? ? "script/ferret_server -e #{rails_env} #{op}" : "RAILS_ENV=#{rails_env} script/ferret_#{op}"
    "cd #{current_path} && #{run_cmd}"
  end

  
  after "deploy:restart", "ferret:restart"
  after "deploy:start",   "ferret:start"
  after "deploy:stop",    "ferret:stop"

  namespace :ferret do
    desc "Restart the ferret server"
    task :restart, :roles => :app do
      stop
      start
    end

    desc "Stop the ferret server"
    task :stop, :roles => :app do
      run ferret_cmd.call("stop")
    end

    desc "Start the ferret server"
    task :start, :roles => :app do
      run ferret_cmd.call("start")
    end
  end
end
