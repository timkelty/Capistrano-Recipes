Capistrano::Configuration.instance.load do
  namespace :util do
    task :migrate_engines, :roles => :db, :only => { :primary => true } do
      run "cd #{current_path} && " +
        "#{rake} RAILS_ENV=#{rails_env} db:migrate:engines"
    end

    task :fix_home_dir_perms, :roles => [:app, :web] do 
      run "chmod 701 /home/#{user}"
      run "chmod -R 755 /home/#{user}/apps/#{application}"
    end

    desc "remote console"   
    task :console, :roles => :app do
      input = ''
      run "cd #{current_path} && ./script/console #{ENV['RAILS_ENV']}" do |channel, stream, data|
        next if data.chomp == input.chomp || data.chomp == ''
        print data
        channel.send_data(input = $stdin.gets) if data =~ /^(>|\?)>/
      end
    end

    desc "tail production log files" 
    task :tail_logs, :roles => :app do
      run "tail -f #{shared_path}/log/production.log" do |channel, stream, data|
        puts  # for an extra line break before the host name
        puts "#{channel[:host]}: #{data}" 
        break if stream == :err    
      end
    end
    desc "Add deploy message to yammer feed"
    task :notify do
      if fetch(:notify_yammer, false)
        require File.dirname(__FILE__) + '/notifier'
        extra_msg = ""
        if scm == "git"
          rev         = real_revision[0, 6]
          extra_msg   = " (http://git.fusionary.com/?p=#{repository.split(':').last};a=commit;h=#{rev})"
        else
          rev = revision 
        end
        deploy_msg = "#deploy #{user} #{application} #{ENV["STAGE"]} by #{ENV['USER']} from #{rev}#{extra_msg}"
        begin; Notifier.say(deploy_msg); rescue; end
      end
    end
  end
end

