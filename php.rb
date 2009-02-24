Capistrano::Configuration.instance.load do
  require File.dirname(__FILE__) + '/util'

  # Default values
  set :keep_releases,   3
  set :app_symlinks,    nil
  set :shared_dirs,     nil

  # Callbacks
  after "deploy",           "deploy:cleanup"
  after "deploy",           "util:notify"
  after "deploy:setup",     "fusionary:setup_shared"
  after "deploy:symlink",   "fusionary:symlink_extras"

  namespace :deploy do
    task :restart do
      puts "This is a no-op in PHP"
    end
  end

  namespace :fusionary do
    desc "Setup additional symlinks to shared directories"
    task :symlink_extras, :roles => [:web] do
      if app_symlinks
        app_symlinks.each { |link| run "ln -nfs #{shared_path}/#{link} #{current_path}/#{link}" }
      end
    end

    desc "Setup the additional shared directories"
    task :setup_shared, :roles => [:web] do
      if shared_dirs
        shared_dirs.each do |dir|
          run "mkdir -p #{shared_path}/#{dir}"
        end
      end
    end
  end # fusionary
end
