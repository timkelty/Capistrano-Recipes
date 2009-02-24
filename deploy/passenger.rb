Capistrano::Configuration.instance.load do
  namespace :deploy do
    desc "Restarting mod_rails with restart.txt"
    task :restart, :roles => :app do
      run "touch #{current_path}/tmp/restart.txt"
    end

    [:start, :stop].each do |t|
      desc "#{t} task is a no-op with mod_rails"
      task t, :roles => :app do ; end
    end
  end
end
