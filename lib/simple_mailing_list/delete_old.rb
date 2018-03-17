class User         < ActiveRecord::Base ; end
class Confirmation < ActiveRecord::Base ; end

module SimpleMailingList
  module System
    private

    def _delete_failed_users(failed_count = 10, time = 5 * 24 * 60 * 60)
      @log.debug "Delete failed users."
      last_failed_at = Time.now - time
      users = User.where("last_failed_at > ? AND failed_count > ?", last_failed_at, failed_count)
      users.each do |user|
        @log.info "user[#{user.mail_address}] was deleted."
      end
      users.destroy_all()
      User.find_each do |user|
        user.failed_count = 0
        user.save
      end
    end

    def _delete_old_confirmations()
      @log.debug "Delete old confirmations."
      time = Time.now - @validity_time
      confirmations = Confirmation.where("created_at < ?", time)
      num = confirmations.size
      confirmations.destroy_all()
      @log.info "#{num} confirmation#{num > 1 ? 's' : ''} #{num > 1 ? 'were' : 'was'} deleted." if num > 0
    end

    def _delete_old_maillogs()
      return unless @maillogs_period >= 0

      @log.debug "Delete old maillogs."
      time = Time.now - @maillogs_period
      num = 0
      maillogs = Dir.glob(File.join(@maillogs_dir, "*", "*.eml")).select do |maillog|
        File.mtime(maillog) < time
      end
      num = maillogs.size
      maillogs.each { |maillog| File.delete(maillog) }
      @log.info "#{num} maillog#{num > 1 ? 's' : ''} #{num > 1 ? 'were' : 'was'} deleted." if num > 0
    end
  end
end
