require "fileutils"

require "active_record"

module SimpleMailingList
  module System
    private

    def _setup()
      ActiveRecord::Base.transaction do |a|
        ActiveRecord::Migration.create_table :users do |t|
          t.text      :mail_address   , null: false
          t.integer   :enabled        , null: false, default: 1
          t.integer   :failed_count   , null: false, default: 0
          t.timestamp :last_failed_at , null: false, default: Time.at(0)
          t.text      :options        , null: false, default: "{}"
          t.timestamps                  null: false
        end

        ActiveRecord::Migration.create_table :confirmations do |t|
          t.text     :mail_address , null: false
          t.text     :check_code   , null: false
          t.text     :mode         , null: false
          t.text     :options      , null: false, default: "{}"
          t.timestamps               null: false
        end

        FileUtils.makedirs(
          %w[
            temp
            register
            delete
            register_check
            delete_check
            forward
            bounced
            unmatched
            error
          ].map do |dir|
            File.join(@maillogs_dir, dir)
          end
        )
      end
      @log.info "Setup successed."
    end

    def _cleanup(delete_maillogs = false)
      ActiveRecord::Base.transaction do |a|
        ActiveRecord::Migration.drop_table(:users)
        ActiveRecord::Migration.drop_table(:confirmations)

        FileUtils.remove_entry_secure(@maillogs_dir, true) if delete_maillogs
      end
      @log.info "Cleanup successed."
    end
  end
end
