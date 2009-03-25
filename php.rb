Capistrano::Configuration.instance.load do
  require File.dirname(__FILE__) + '/util'

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

  namespace :db do
    desc "Copy database from server to local machine"
    task :sync_to_local, :roles => [:web] do
      continue = Capistrano::CLI.ui.ask "This task will overwrite your existing #{ENV["STAGE"]} data. Proceed? (y/N)"
      if continue =~ /[Yy]/

        set_config_vars
        mysql_cmd = fetch(:mysql_cmd, "mysql")
        prompt_for_mysql_config

        mysql_dump    = mysqldump(remote_path,  remote_db,
                                  :u => remote_user, :p => remote_passwd, :compress => true)

        mysql_import  = mysqlimport(local_path, local_db, :mysql_cmd => mysql_cmd,
                                    :u => local_user, :p => local_passwd,
                                    :compress => true)

        run mysql_dump do |ch, _, out| 
          puts out 
        end

        download remote_path, local_path

        run "rm #{remote_path}"

        puts "Running local mysql import from #{ENV["STAGE"]} data..." 
        `#{mysql_import}`
        `rm #{uncompressed_path(local_path)}` 
      end
    end

    desc "Copy local database to server" 
    task :sync_to_remote, :roles => [:web] do 
      continue = Capistrano::CLI.ui.ask "CAUTION!!!! This task will overwrite your existing #{ENV["STAGE"]} data REMOTELY. Proceed? (y/N)"
      if continue =~ /[Yy]/
        set_config_vars
        mysql_cmd = fetch(:mysql_cmd, "mysql")
        prompt_for_mysql_config

        mysql_dump    = mysqldump(local_path,  local_db,
                                  :u => local_user, :p => local_passwd,
                                  :compress => true)

        mysql_import  = mysqlimport(remote_path, remote_db,
                                    :u => remote_user, :p => remote_passwd, :mysql_cmd => mysql_cmd,
                                    :compress => true)

        `#{mysql_dump}`
        upload local_path, remote_path

        puts "Running remote mysql import from #{ENV["STAGE"]} data..." 
        run mysql_import
        run "rm #{uncompressed_path(remote_path)}"
      end


    end

    def prompt_for_mysql_config 
      puts "Please provide the details to your database setup..."
      set :local_db,      Capistrano::CLI.ui.ask("LOCAL mysql database:")
      set :local_user,    Capistrano::CLI.ui.ask("LOCAL mysql user:")
      set :local_passwd,  Capistrano::CLI.password_prompt("LOCAL mysql password:")
      set :remote_db,     Capistrano::CLI.ui.ask("REMOTE mysql database:")
      set :remote_user,   Capistrano::CLI.ui.ask("REMOTE mysql user:")
      set :remote_passwd, Capistrano::CLI.password_prompt("REMOTE mysql password:")
    end

    def set_config_vars
      set :remote_path,       "#{deploy_to}/#{ENV["STAGE"]}/current/tmp/#{ENV["STAGE"]}_dump.sql.gz"
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
        # Due to lame mysql command line requirement
        ary << (k == :p ? "-#{k}#{v}" : "-#{k} #{v}")
      end.join(" ")
    end

    def uncompressed_path(orig_path)
      File.dirname(orig_path) + "/" + File.basename(orig_path, ".gz")
    end

  end #db

end
