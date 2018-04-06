require "yaml"
require "logger"

require "mail"
require "active_record"
require "thor"

require "simple_mailing_list/configfile"
require "simple_mailing_list/version"

module SimpleMailingList
  class CLI < Thor
    include SimpleMailingList::System
    package_name "SimpleMailingList"
    default_command :main_jobs
    map "--version" => :version
    class_option :configfile,
      aliases: "-c",
      default: DEFAULT_CONFIGFILE,
      desc: "configfile(YAML format) path."

    def self.exit_on_failure?
      true
    end

    desc "setup", "create tables and maillog_dir."
    def setup()
      require "simple_mailing_list/setup"
      load_configfile(options[:configfile])
      _setup()
    end

    desc "cleanup", "drop tables."
    option :delete_maillogs,
      default: false,
      type: :boolean
    def cleanup()
      require "simple_mailing_list/setup"
      load_configfile(options[:configfile])
      _cleanup(options[:delete_maillogs])
    end

    desc "add_user MAIL_ADDRESS [JSON_FORMAT_OPTION]", "add a user."
    def add_user(address, user_options="{}")
      require "simple_mailing_list/main"
      require "json"
      load_configfile(options[:configfile])
      _add_user(address, JSON.parse(user_options))
    end

    desc "delete_user MAIL_ADDRESS", "delete a user."
    def delete_user(address)
      require "simple_mailing_list/main"
      load_configfile(options[:configfile])
      _delete_user(address)
    end

    desc "disable_failed_users", "disable users who do not receive mails."
    option :failed_count,
      aliases: "-f",
      default: 10,
      type: :numeric
    option :failed_time,
      aliases: "-t",
      default: 5 * 24 * 60 * 60,
      type: :numeric
    option :reset,
      default: false,
      type: :boolean
    def disable_failed_users()
      require "simple_mailing_list/delete_old"
      load_configfile(options[:configfile])
      _disable_failed_users(options[:failed_count], options[:failed_time], options[:reset])
    end

    desc "delete_old_confirmations", "delete old confirmations."
    def delete_old_confirmations()
      require "simple_mailing_list/delete_old"
      load_configfile(options[:configfile])
      _delete_old_confirmations()
    end

    desc "delete_old_maillogs", "delete old maillogs."
    def delete_old_maillogs()
      require "simple_mailing_list/delete_old"
      load_configfile(options[:configfile])
      _delete_old_maillogs()
    end

    desc "check_mails", "check new mails."
    def check_mails()
      require "simple_mailing_list/main"
      load_configfile(options[:configfile])
      _check_mails()
    end

    desc "check_mail_file [MAIL_FILE]", "check new mail from file."
    def check_mail_file(mailfile)
      require "simple_mailing_list/main"
      load_configfile(options[:configfile])
      _check_mail_file(mailfile)
    end

    desc "main_jobs", "check new mails and delete old confirmations and maillogs."
    def main_jobs()
      require "simple_mailing_list/main"
      require "simple_mailing_list/delete_old"
      load_configfile(options[:configfile])
      _check_mails()
      _delete_old_confirmations()
      _delete_old_maillogs()
    end

    desc "loop_main_jobs", "loop main_jobs."
    option :sleep_time,
      aliases: "-s",
      default: 10,
      type: :numeric,
      desc: "wait time on a loop."
    def loop_main_jobs()
      require "simple_mailing_list/main"
      require "simple_mailing_list/delete_old"
      load_configfile(options[:configfile])
      loop do
        _check_mails(false)
        _delete_old_confirmations()
        _delete_old_maillogs()
        sleep options[:sleep_time]
      end
    end

    desc "version", "output version."
    def version()
      puts "Simple Mailing List - #{SimpleMailingList::VERSION}"
    end
  end
end
