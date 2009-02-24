Capistrano::Configuration.instance.load do
  require 'mongrel_cluster/recipes'
  set :mongrel_port,    nil
  set(:mongrel_conf)    { "#{shared_path}/config/mongrel_cluster.yml" }
  set(:mongrel_user)    { user }
  set(:mongrel_group)   { user }

  before "deploy:restart",  "deploy:web:disable"
  after "deploy:setup",     "mongrel:cluster:configure"
  after "deploy:restart",   "deploy:web:enable"

  # Override start and restart mongrel cluster to clean pid files
  task :start_mongrel_cluster, :roles => :app do
    cmd = "mongrel_rails cluster::start -C #{mongrel_conf} --clean"
    invoke_command cmd, :via => run_method
  end
  
  task :restart_mongrel_cluster, :roles => :app do
    cmd = "mongrel_rails cluster::restart -C #{mongrel_conf} --clean"
    invoke_command cmd, :via => run_method
  end

  namespace :deploy do  
    task :restart, :roles => :app do
      cmd  = "mongrel_rails cluster::restart -C #{mongrel_conf}"
      invoke_command cmd, :via => run_method
    end

    task :spinner, :roles => :app do
      cmd = "mongrel_rails cluster::restart -C #{mongrel_conf}"
      invoke_command cmd, :via => run_method
    end
  end
end
