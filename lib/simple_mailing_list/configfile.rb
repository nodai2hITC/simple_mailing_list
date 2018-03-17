module SimpleMailingList
  module System
    DEFAULT_CONFIGFILE = "config.yaml"

    private

    def load_configfile(configfile)
      return if @path

      # basic
      config = YAML.load(File.read(configfile, encoding: "utf-8"))
      @path = Dir.getwd

      # log
      config["log"] ||= {}
      file = config["log"]["filename"] ?
        File.expand_path(Time.now.strftime(config["log"]["filename"]), @path) : STDOUT
      @log = (config["log"]["rotation"].is_a? Integer) ?
        Logger.new(file, config["log"]["rotation"], config["log"]["shift_size"] || 1048576) :
        Logger.new(file, config["log"]["rotation"] || 0)
      if config["log"]["level"]
        @log.level = config["log"]["level"].is_a?(String) ?
          %w[debug info warn error fatal].index(config["log"]["level"].downcase) :
          config["log"]["level"]
      end

      # others
      @lockfile                 = config["lockfile"]
      @maillogs_dir             = File.expand_path(config["maillogs_dir"] || "maillogs", @path)
      @maillogs_period          = config["maillogs_period"] || -1

      @validity_time            = config["validity_time"] || 86400
      @max_check_times          = config["max_check_times"] || 5

      @sleep_time1              = config["sleep_time1"] || 0.1
      @sleep_time2              = config["sleep_time2"] || 1.5
      @permitted_users          = config["permitted_users"]
      @registered_user_only     = !!config["registered_user_only"]
      @use_address_camouflage   = !!config["use_address_camouflage"]
      @enable_html_mail         = !!config["enable_html_mail"]

      @receive_servers          = config["receive_servers"] || []
      @deliver_server           = config["deliver_server"] ||
        { "protocol" => "sendmail", "charset" => "utf-8", "options" => {} }
      
      @register = config["register"] || []
      @register_confirm_subject = config["register_confirm_subject"] || ""
      @register_confirm_body    = config["register_confirm_body"] || ""
      @register_success_subject = config["register_success_subject"] || ""
      @register_success_body    = config["register_success_body"] || ""

      @delete                   = config["delete"] || []
      @delete_confirm_subject   = config["delete_confirm_subject"] || ""
      @delete_confirm_body      = config["delete_confirm_body"] || ""
      @delete_success_subject   = config["delete_success_subject"] || ""
      @delete_success_body      = config["delete_success_body"] || ""

      @forward                  = config["forward"] || []
      @reply_to_address         = config["reply_to_address"]

      # database
      if config["database_require"]
        require config["database_require"]
      else
        case config["database"]["adapter"]
        when "mysql2"
          require "mysql2"
        when "postgresql"
          require "pg"
        when "sqlite3"
          require "sqlite3"
        else
          require config["database"]["adapter"]
        end
      end
      ActiveRecord::Base.establish_connection(config["database"])

      # mail server
      @receive_servers = Array(config["receive_server"]) if config["receive_server"]
      deliver_server = @deliver_server
      Mail.defaults do
          delivery_method(deliver_server["protocol"].to_sym,
                          deliver_server["options"].symbolize_keys)
      end
    end
  end
end
