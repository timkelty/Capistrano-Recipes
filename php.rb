Capistrano::Configuration.instance.load do
  require File.dirname(__FILE__) + '/util'
  require File.dirname(__FILE__) + '/db'

  # Default values
  set :keep_releases,         3
  set :app_symlinks,          nil
  set :shared_dirs,           nil
  set :extra_permissions,     nil

  # Callbacks
  after "deploy",                 "deploy:cleanup"
  after "deploy",                 "util:notify"
  after "deploy:setup",           "fusionary:setup_shared"
  after "fusionary:setup_shared", "fusionary:set_extra_permissions"
  after "deploy:symlink",         "fusionary:symlink_extras"

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

    desc "Set permissions on directories"
    task :set_extra_permissions, :roles => [:web] do
      if extra_permissions
        extra_permissions.each do |dir, permissions|
          run "chmod -R #{permissions} #{shared_path}/#{dir}"
        end
      end
    end
  end # fusionary
end
