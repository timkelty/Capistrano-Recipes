require 'active_support'
require 'fileutils'

Capistrano::Configuration.instance.load do

  namespace :db do
    desc "Copy database from server to local machine"
    task :sync_to_local, :roles => [:db] do
      set_config_vars

      if supress_warnings == false
        continue = Capistrano::CLI.ui.ask "This task will overwrite your existing #{rails_env} data. Proceed? (y/n)"
      else
        continue = "Y"
      end

      if continue =~ /[Yy]/
        mysql_dump    = mysqldump(remote_dump_path,  remote_dbconfig['database'],
                                  :u => remote_dbconfig['username'], :p => remote_dbconfig['password'],
                                  :h => remote_dbconfig['host'], :compress => true, :ignore_tables => ENV["IGNORE_TABLES"])

        mysql_import  = mysqlimport(local_path, local_dbconfig['database'], :mysql_cmd => mysql_cmd,
                                    :u => local_dbconfig['username'], :p => local_dbconfig['password'],
                                    :h => local_dbconfig['host'], :compress => true)

        run mysql_dump do |ch, _, out|
          puts out
        end

        download remote_dump_path, local_path

        run "rm #{remote_dump_path}"

        createdb(local_dbconfig['database'],
                 local_dbconfig['username'],
                 local_dbconfig['password'],
                 :mysqladmin_cmd => fetch(:mysqladmin_cmd, nil))

        puts "Running local mysql import from #{rails_env} data..."
        `#{mysql_import}`

        `rm #{uncompressed_path(local_path)}`
      end
    end

    def createdb(database, user, password, options={})
      puts "creating #{database} database"
      create_cmd = options.delete(:mysqladmin_cmd) || "mysqladmin"
      pw_string = password !~ /\S/ ? "" : "-p#{shell_escape(password)}"
      %x{mysqladmin -u #{user} #{pw_string} create #{database}}
    end

    def mysqldump(dumpfile, database, options={})
      cmd           = options.delete(:mysqldump_cmd) || "mysqldump"
      compress      = options.delete(:compress)
      ignore_tables = options.delete(:ignore_tables).to_s.split(/,| /).reject { |s| s !~ /\S/ }
      opts          = create_option_string(options)
      dump_cmd      = "#{cmd} #{opts} #{database}"
      dump_cmd     += " " + ignore_tables.map {|t| "--ignore-table=#{database}.#{t}"}.join(" ") if ignore_tables.any?
      dump_cmd     += " | gzip -f"  if compress
      dump_cmd     += " > #{dumpfile}"
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
      options.reject { |k, v| v !~ /\S/ }.inject([]) do |ary, (k, v)|
        # Due to lame mysql command line requirement
        ary << (k == :p ? "-#{k}#{shell_escape(v)}" : "-#{k} #{shell_escape(v)}")
      end.join(" ")
    end

    def uncompressed_path(orig_path)
      File.dirname(orig_path) + "/" + File.basename(orig_path, ".gz")
    end

    def set_config_vars
      set :database_yml_path,   fetch(:database_yml_path, "config/database.yml")
      set :mysql_cmd,           "mysql"
      set :supress_warnings,    fetch(:supress_warnings, false)

      database_yml = ""
      run "cat #{shared_path}/config/database.yml" do |channel, stream, data|
        database_yml = data
      end
      set :rails_env,         'development'
      set :remote_dbconfig,   load_database_yml(database_yml, rails_env)
      set :local_dbconfig,    load_database_yml(File.open(database_yml_path), rails_env)
      set :remote_dump_path,  "#{current_path}/tmp/#{rails_env}_dump.sql.gz"

      FileUtils.mkdir_p(File.join(Dir.pwd, "tmp"))
      set :local_path,        'tmp/' + File.basename(remote_dump_path)
    end

    def load_database_yml(database_yml, env)
      result = YAML::load(database_yml)[env]
      if result.respond_to?(:[]=)
        result
      else
        load_database_yml(database_yml, result.to_s)
      end
    end
  end

  def shell_escape(str)
    String(str).gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/n, '\\').
      gsub(/\n/, "'\n'").
      sub(/^$/, "''")
  end
end
