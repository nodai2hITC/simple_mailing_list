module SimpleMailingList
  module System
    private

    def lock()
      if @lockfile
        open(File.expand_path(@lockfile, @path), "w") do |lockfile|
          if lockfile.flock(File::LOCK_EX | File::LOCK_NB)
            @log.debug("Lock successed.")
            yield
            lockfile.flock(File::LOCK_UN)
            @log.debug("Unlocked.")
          else
            @log.debug("Lock failed.")
          end
        end
      else
        yield
      end
    end
  end
end
