Capistrano::Configuration.instance.load do
  require 'yaml'
  require File.dirname(__FILE__) + '/util'
  require File.dirname(__FILE__) + '/ferret' if (File.exist?('script/ferret_server') || File.exist?('script/ferret_start'))

  #TODO: Remove this when we migrate all of our apps to passenger
  require File.dirname(__FILE__) + (fetch(:using_passenger, true) ? '/deploy/passenger' : '/deploy/mongrel')

  set :app_symlinks,    nil
  set :keep_releases,   3
  set :use_sudo,        false
  set :rails_env,       'development'

  # Callbacks
  after "deploy",               "deploy:cleanup"
  after "deploy",               "util:notify"
  after "deploy:update_code",   "fusionary:symlink_configs"
  after "deploy:symlink",       "fusionary:symlink_extras"
  after "deploy:setup",         "fusionary:create_shared_config"
  after "deploy:setup",         "fusionary:setup_symlinks"

  namespace :fusionary do 
    desc "symlink configs from shared to release directory"
    task :symlink_configs, :roles => [:web, :app] do
      %w[database.yml mongrel_cluster.yml settings.yml gmaps_api_key.yml].each do |config_file|
        run "ln -nfs #{shared_path}/config/#{config_file} #{release_path}/config"
      end
    end

    desc "create shared config directory" 
    task :create_shared_config, :roles => [:app, :web] do
      run "mkdir -p #{shared_path}/config"
    end

    desc "Setup additional symlinks for app"
    task :setup_symlinks, :roles => [:app, :web] do
      if app_symlinks
        app_symlinks.each do |link|
          if link.split("/").last.include? "."
            run "mkdir -p #{shared_path}/#{File.dirname(link)}"
          else
            run "mkdir -p #{shared_path}/#{link}"
          end
        end
      end
    end

    task :symlink_extras, :roles => [:app, :web] do
      if app_symlinks
        app_symlinks.each { |link| run "ln -nfs #{shared_path}/#{link} #{current_path}/#{link}" }
      end
    end
  end

  namespace :db do

    

    desc "Copy database from server to local machine"
    task :sync_to_local, :roles => [:db] do
      continue = Capistrano::CLI.ui.ask "This task will overwrite your existing #{rails_env} data. Proceed? (y/N)"
      if continue =~ /[Yy]/

        set_config_vars

        mysql_dump    = mysqldump(remote_path,  remote_dbconfig['database'],
                                  :u => remote_dbconfig['username'], :p => remote_dbconfig['password'],
                                  :h => remote_dbconfig['host'], :compress => true)

        mysql_import  = mysqlimport(local_path, local_dbconfig['database'], :mysql_cmd => mysql_cmd,
                                  :u => local_dbconfig['username'], :p => local_dbconfig['password'],
                                  :h => local_dbconfig['host'], :compress => true)

        run mysql_dump do |ch, _, out| 
          puts out 
        end

        download remote_path, local_path

        run "rm #{remote_path}"

        puts "Running local mysql import from #{rails_env} data..." 
        `#{mysql_import}`
        `rm #{uncompressed_path(local_path)}` 
      end
    end

    desc "Copy local database to server" 
    task :sync_to_remote, :roles => [:db] do 
      continue = Capistrano::CLI.ui.ask "CAUTION!!!! This task will overwrite your existing #{rails_env} data REMOTELY. Proceed? (y/N)"
      if continue =~ /[Yy]/
        set_config_vars

        mysql_dump    = mysqldump(local_path,  local_dbconfig['database'],
                                  :u => local_dbconfig['username'], :p => local_dbconfig['password'],
                                  :h => local_dbconfig['host'], :compress => true, :mysqldump_cmd => "mysqldump5")

        mysql_import  = mysqlimport(remote_path, remote_dbconfig['database'], :mysql_cmd => "mysql",
                                  :u => remote_dbconfig['username'], :p => remote_dbconfig['password'],
                                  :h => remote_dbconfig['host'], :compress => true)

        `#{mysql_dump}`
        upload local_path, remote_path

        puts "Running remote mysql import from #{rails_env} data..." 
        run mysql_import
        run "rm #{uncompressed_path(remote_path)}"
      end


    end

    def set_config_vars
        fetch(:mysql_cmd, "mysql")

        database_yml  = ""
        run "cat #{shared_path}/config/database.yml" do |_, _, database_yml| end
        set :remote_dbconfig,   YAML::load(database_yml)[rails_env]
        set :local_dbconfig,    YAML::load(File.open("config/database.yml"))[rails_env]
        set :remote_path,       "#{current_path}/tmp/#{rails_env}_dump.sql.gz"
        set :local_path,        'tmp/' + File.basename(remote_path)
    end

    def mysqldump(dumpfile, database, options={})
      cmd         = options.delete(:mysqldump_cmd) || "mysqldump"
      compress  =   options.delete(:compress)
      opts      =   create_option_string(options)
      dump_cmd  =   "#{cmd} #{opts} #{database}"
      dump_cmd +=   " | gzip -f"  if compress
      dump_cmd +=   " > #{dumpfile}"
    end

    def mysqlimport(dumpfile, database, options={})
      compress    = options.delete(:compress)
      cmd         = options.delete(:mysql_cmd) || "mysql"
      if compress
        import_cmd = "gunzip -f #{dumpfile} && "
        dumpfile = File.dirname(dumpfile) + "/" + File.basename(dumpfile, ".gz") 
      else
        import_cmd = ""
      end

      import_cmd  += "#{cmd} #{create_option_string(options)} #{database} < #{dumpfile}"
    end

    def create_option_string(options)
      options.inject([]) do |ary, (k, v)|
        # Due to lame mysql command like requirement
        ary << (k == :p ? "-#{k}#{v}" : "-#{k} #{v}")
      end.join(" ")
    end

    def uncompressed_path(orig_path)
      File.dirname(orig_path) + "/" + File.basename(orig_path, ".gz")
    end

  end 
end
