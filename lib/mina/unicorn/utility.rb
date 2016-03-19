# Ported from: https://github.com/sosedoff/capistrano-unicorn/blob/master/lib/capistrano-unicorn/utility.rb

module Mina
  module Unicorn
    module Utility

      # Run a command as the :unicorn_user user if :unicorn_user is a string.
      # Otherwise run as default (:user) user.
      #
      def try_unicorn_user
        "sudo -u #{unicorn_user}" if unicorn_user.kind_of?(String)
      end

      # Check if a remote process exists using its pid file
      #
      def remote_process_exists?(pid_file)
        "[ -e #{pid_file} ] && #{try_unicorn_user} kill -0 `cat #{pid_file}` > /dev/null 2>&1"
      end

      # Stale Unicorn process pid file
      #
      def old_unicorn_pid
        "#{unicorn_pid}.oldbin"
      end

      # Command to check if Unicorn is running
      #
      def unicorn_is_running?
        remote_process_exists?(unicorn_pid)
      end

      # Command to check if stale Unicorn is running
      #
      def old_unicorn_is_running?
        remote_process_exists?(old_unicorn_pid)
      end

      # Get unicorn master process PID (using the shell)
      #
      def get_unicorn_pid(pid_file=unicorn_pid)
        "`cat #{pid_file}`"
      end

      # Get unicorn master (old) process PID
      #
      def get_old_unicorn_pid
        get_unicorn_pid(old_unicorn_pid)
      end

      # Send a signal to a unicorn master processes
      #
      def unicorn_send_signal(signal, pid=get_unicorn_pid)
        "#{try_unicorn_user} kill -s #{signal} #{pid}"
      end

      # Kill Unicorns in multiple ways O_O
      #
      def kill_unicorn(signal)
        script = <<-END
          if #{unicorn_is_running?}; then
            echo "-----> Stopping Unicorn...";
            #{unicorn_send_signal(signal)};
          else
            echo "-----> Unicorn is not running.";
          fi;
        END

        script
      end

      # Start the Unicorn server
      #
      def start_unicorn
        %Q%
          if [ -e "#{unicorn_pid}" ]; then
            if #{try_unicorn_user} kill -0 `cat #{unicorn_pid}` > /dev/null 2>&1; then
              echo "-----> Unicorn is already running!";
              exit 0;
            fi;

            #{try_unicorn_user} rm #{unicorn_pid};
          fi;

          echo "-----> Starting Unicorn...";
          cd #{deploy_to}/#{current_path} && #{try_unicorn_user} BUNDLE_GEMFILE=#{bundle_gemfile} #{unicorn_cmd} -c #{unicorn_config} -E #{unicorn_env} -D;
        %
      end

      # Restart the Unicorn server
      #
      def restart_unicorn
        %Q%
          if #{unicorn_is_running?}; then
            echo "-----> Duplicating Unicorn...";

            CURRENT_PID=#{get_unicorn_pid}
            echo "-----> Old PID: $CURRENT_PID";

            #{unicorn_send_signal('USR2')};

            t=1
            oldbinfound="false"
            oldbindisapeared="false"
            newpidexists="false"
            while [[ $t -lt #{unicorn_restart_sleep_time}00 ]] && [[ $newpidexists == "false" ]] ; do
              [[ $oldbinfound == "false" ]] && [[ -x #{old_unicorn_pid} ]] && oldbinfound="true"
              [[ $oldbinfound == "true" ]] && [[ ! -x #{old_unicorn_pid} ]] && oldbindisapeared="true"
              [[ $oldbindisapeared == "true" ]] && [[ -x #{unicorn_pid} ]] && newpidexists="true"
              (( t += 1 ))
              echo "a $oldbinfound b $oldbindisapeared c $newpidexists d $t"
            done;
            echo "-----> New PID: #{get_unicorn_pid}";
            [[ $CURRENT_PID == #{get_unicorn_pid} ]] && exit 1 || exit 0

          else
            #{start_unicorn}
          fi;
        %
      end

    end
  end
end
