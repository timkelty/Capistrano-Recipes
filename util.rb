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

    desc "Add deploy message to campfire"
    task :notify do
      if token = fetch(:campfire_token, nil)
        begin
          require 'tinder'

          # First 6 digits of commit hash
          rev         = real_revision[0, 6]
          campfire = Tinder::Campfire.new 'fusionary', :token => token, :ssl => true
          room = campfire.find_room_by_name(fetch(:campfire_room))
          room.speak "*** DEPLOY: #{user}/#{application} #{ENV['STAGE']} by #{ENV['USER']} (#{rev}/#{revision})"
        rescue LoadError
          puts "Please install the tinder gem to get campfire deploy notifications (gem install tinder)"
        end
      end
    end

    desc "capture the pending scm changes for the tracker"
    task :capture_pending_changes do
      from = source.next_revision(current_revision)
      log = %x{#{"git log --pretty=format:\"%h: %s -- %an\" #{from}.."}}
      set :scm_log, log
    end

    desc "post deployment info to tracker"
    task :notify_tracker do
      tracker_url = fetch(:deployment_tracker_url, nil)
      api_key = fetch(:deployment_tracker_api_key, nil)

      unless tracker_url && api_key
        raise "Please set deployment tracker host and API key in deploy.rb"
      end

      gitconfig = File.join(ENV['HOME'], ".gitconfig")
      gitconfig_hash = {}
      if File.exist?(gitconfig)
        File.open(gitconfig, "r") do |f|
          f.readlines.each do |line|
            if match = line.match(/(.*)\=(.*)/)
              gitconfig_hash[match[1].strip] = match[2].strip
            end
          end
        end
      end
      username = gitconfig_hash["name"] || ENV['USER']
      email = gitconfig_hash["email"]

      require "net/http"
      require "uri"
      tracker_host = URI.parse(tracker_url)
      post_data = {
        "api_key" => api_key,
        "deployment[remote_user]" => user,
        "deployment[deployed_by_name]" => username,
        "deployment[deployed_by_email]" => email,
        "deployment[application]" => application,
        "deployment[stage]" => ENV['STAGE'],
        "deployment[rev]" => real_revision[0, 6],
        "deployment[revision]" => revision,
        "deployment[changelog]" => fetch(:scm_log, nil)
      }

      begin
        response = Net::HTTP.post_form(tracker_host, post_data)
        if response.code != "201"
          puts response.body.inspect
          raise RuntimeError
        end
      rescue
        puts "******** ERROR: Deployment was not tracked. ********"
      end
    end

    desc "Sync remote assets to local"
    task :sync_assets_to_local, :role => :web do
      continue = Capistrano::CLI.ui.ask "This task will overwrite all of your local assets. Proceed? (y/n)"
      if continue =~ /[Yy]/
        return unless asset_dirs
        asset_dirs.each do |asset_dir|
          excluded = asset_dir.fetch(:exclude, []).inject("") {|str, e| str << " --exclude #{e}"}
          `rsync -avz #{user}@#{asset_dir[:server]}:#{asset_dir[:directory]} #{asset_dir[:local_directory]} #{excluded}`
        end
      end
    end
  end
end

