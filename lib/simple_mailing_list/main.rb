require "json"
require "securerandom"
require "digest/sha2"

require "liquid"

require "simple_mailing_list/lock"

class User         < ActiveRecord::Base ; end
class Confirmation < ActiveRecord::Base ; end

module SimpleMailingList
  module System
    private
    
    def _check_mails(thread_join = true)
      threads = receive_mails.map do |mail_filename|
        Thread.start(File.join(@maillogs_dir, "temp", mail_filename)) do |filename|
          _check_mail_file(filename)
        end
      end
      threads.each { |thread| thread.join } if thread_join
    end

    def _check_mail_file(filename)
      mail = Mail.read(filename)
      begin
        return if  register_mail(mail, filename)
        return if    delete_mail(mail, filename)
        return if   confirm_mail(mail, filename)
        return if   bounced_mail(mail, filename)
        return if   forward_mail(mail, filename)
        return if unmatched_mail(mail, filename)
      rescue => e
        move_mail_file(filename, "error")
        @log.error "Error Mail[#{File.basename(filename)}]!\n  #{error_message(e)}"
      end
    end

    def find_rule(rules, mail)
      mail_body = mail.body ? mail.body.decoded.to_s : ""
      mail_body += mail.text_part.decoded.to_s if mail.text_part
      return rules.find do |rule|
        (!rule["address"] || Array(mail.to).index(rule["address"])) &&
        (!rule["subject"] || mail.subject.to_s.index(rule["subject"])) &&
        (!rule["body"   ] || mail_body.index(rule["body"]))
      end
    end

    def register_mail(mail, filename)
      rule = find_rule(@register, mail)
      address = Array(mail.from).first.to_s
      return false if !rule || address.empty?
      regisiter_options = rule["options"] || {}
      @log.info "New register mail from #{address}."
      return true if Confirmation.where(mail_address: address).size >= @max_check_times

      check_code = create_check_code()
      Confirmation.new(
        mail_address: address,
        check_code:   check_code,
        mode:         "register",
        options:      JSON.generate(regisiter_options)
      ).save!

      mail = create_mail(
        to:      address,
        subject: @register_confirm_subject,
        body:    @register_confirm_body,
        options: regisiter_options.merge({ "checkcode" => check_code })
      )
      mail.subject += check_code unless mail.subject.index(check_code)
      mail.deliver!
      sleep @sleep_time1
      move_mail_file(filename, "register")
      return true
    end

    def delete_mail(mail, filename)
      rule = find_rule(@delete, mail)
      address = Array(mail.from).first.to_s
      return false if !rule || address.empty?
      @log.info "New delete mail from #{address}."
      return true if Confirmation.where(mail_address: address).size >= @max_check_times

      check_code = create_check_code()
      Confirmation.new(
        mail_address: address,
        check_code:   check_code,
        mode:         "delete",
        options:      "{}"
      ).save!

      mail = create_mail(
        to:      address,
        subject: @delete_confirm_subject,
        body:    @delete_confirm_body,
        options: { "checkcode" => check_code }
      )
      mail.subject += check_code unless mail.subject.index(check_code)
      mail.deliver!
      sleep @sleep_time1
      move_mail_file(filename, "delete")
      return true
    end

    def confirm_mail(mail, filename)
      address = Array(mail.from).first.to_s
      return false if address.empty?
      subject = mail.subject.to_s
      body = mail.body ? mail.body.decoded : ""
      body += mail.text_part.decoded.to_s if mail.text_part

      Confirmation.where(mail_address: address).each do |confirmation|
        check_code = confirmation.check_code
        next unless subject.index(check_code) || body.index(check_code)

        confirm_options = {}
        subject_text, body_text = case confirmation.mode
        when "register"
          @log.info "New register check mail from #{address}."
          confirm_options = JSON.parse(confirmation.options)
          _add_user(address, confirm_options)
          [@register_success_subject, @register_success_body]
        when "delete"
          @log.info "New delete check mail from #{address}."
          _delete_user(address)
          [@delete_success_subject, @delete_success_body]
        else
          next
        end

        create_mail(
          to:       address,
          subject:  subject_text,
          body:     body_text,
          reply_to: @reply_to_address,
          options:  confirm_options
        ).deliver!
        sleep @sleep_time1

        move_mail_file(filename, "#{confirmation.mode}_check")
        confirmation.destroy
        return true
      end

      return false
    end

    def bounced_mail(mail, filename)
      unless mail.bounced?
        return false
      end

      matched = mail.final_recipient.to_s.match(/;\s*([^@]+@[^@]+)/)
      if matched
        mail_address = matched[1]
        @log.warn "Bounced mail[#{File.basename(filename)}] from #{mail_address}."
        User.where(mail_address: mail_address).each do |user|
          user.failed_count += 1
          user.last_failed_at = Time.now
          user.save
        end
      else
        @log.warn "Bounced mail[#{File.basename(filename)}]."
      end
      move_mail_file(filename, "bounced")
      return true
    end

    def forward_mail(mail, filename)
      rule = find_rule(@forward, mail)
      address = Array(mail.from).first.to_s
      return false if !rule || address.empty?
      forward_options = rule["options"] || {}
      subject = mail.subject.to_s
      @log.info "New forward mail from #{address}."
      if @permitted_users
        permitted_user = @permitted_users.find do |user|
          (!user["address"]    || user["address"] == address) &&
          (!user["check_code"] || subject.index(["check_code"]))
        end
        return true unless permitted_user
        subject.sub!(permitted_user["check_code"], "") if permitted_user["check_code"]
      elsif @registered_user_only
        return true unless User.find_by(mail_address: address)
      end
      danger_ext = /\.(exe|com|bat|cmd|vbs|vbe|js|jse|wsf|wsh|msc|jar|hta|scr|cpl|lnk)$/i
      if mail.has_attachments?
        attachment = mail.attachments.to_a.find do |attachment|
          attachment.filename.to_s.match(danger_ext)
        end
        if attachment
          @log.warn("Contains danger attachment![#{attachment}@#{File.basename(filename)}]")
          return true
        end
      end

      sendmail = create_forward_mail(mail, subject)

      users = User.where(enabled: 1).to_a.select do |user|
        user_options = JSON.parse(user.options)
        !forward_options.keys.any?{ |key| forward_options[key] != user_options[key] }
      end
      users.map! { |user| user.mail_address }
      users.uniq!
      users.delete(address)

      domains = { "???" => [] }
      users.each do |user|
        domain = user.match(/@([^@]+)$/) ? $1 : "???"
        domains[domain] ||= []
        domains[domain].push(user)
      end
      max = domains.values.map(&:size).max
      domains["???"][max] = address
      0.upto(max) do |i|
        time = Time.now
        domains.each_value do |address_array|
          mail_address = address_array[i]
          next unless mail_address
          
          @log.debug "Send to #{mail_address}"
          sendmail.to = mail_address
          begin
            sendmail.deliver!
          rescue => e
            @log.warn "Sending Error!(#{mail_address})\n  #{error_message(e)}"
            User.where(mail_address: mail_address).each do |user|
              user.failed_count += 1
              user.last_failed_at = Time.now
              user.save
            end
          end
          sleep @sleep_time1
        end
        next if Time.now - time > @sleep_time2 || i+1 == max
        sleep time - Time.now + @sleep_time2
      end
      @log.info "Forward mails to #{users.size + 1} user#{users.size > 0 ? 's' : ''}."
      move_mail_file(filename, "forward")
      return true
    end

    def unmatched_mail(mail, filename)
      address = Array(mail.from).first.to_s
      @log.warn "Unmatched mail[#{File.basename(filename)}] from #{address}."
      move_mail_file(filename, "unmatched")
      return true
    end

    def _add_user(address, user_options = {})
      user = User.new
      user.mail_address = address
      user.options      = JSON.generate(user_options)
      user.save!
      @log.info "Add user[#{address}]."
    end

    def _delete_user(address)
      User.where(mail_address: address).destroy_all()
      @log.info "Delete user[#{address}]."
    end

    def receive_mails()
      mail_files = []
      lock do
        @receive_servers.each do |server|
          begin
            name = "#{server['options']['user_name']}@#{server['options']['address']}"
            @log.debug "Check mails to #{name}."
            Mail.defaults do
              retriever_method(server["protocol"].to_sym, server["options"].symbolize_keys)
            end
            Mail.all(delete_after_find: true).each do |mail|
              filename = mail_filename(mail)
              File.binwrite(File.join(@maillogs_dir, "temp", filename), mail.raw_source)
              @log.info "I got new mail[#{filename}]."
              mail_files.push(filename)
            end
          rescue => e
            @log.error "Mail Check Error!(#{name})\n  #{error_message(e)}"
          end
        end
      end
      return mail_files
    end

    def create_mail(from: nil, to: nil, subject: "", body: nil, reply_to: nil, options: {})
      mail = Mail.new
      mail.charset = @deliver_server["charset"] || "utf-8"
      from = @deliver_server["address"] unless from
      mail.from = options["from"] = from if from
      mail.to   = options["to"  ] = to   if to
      mail.reply_to = reply_to if reply_to
      mail.subject = render_text(subject, options)
      mail.body    = render_text(body   , options) if body
      return mail
    end

    def create_forward_mail(mail, subject)
      from = @use_address_camouflage ? Array(mail.from).first.to_s : nil
      new_mail = create_mail(
        from: from,
        subject: subject,
        reply_to: @use_address_camouflage ? nil : @reply_to_address
      )
      new_mail.in_reply_to = mail.in_reply_to if mail.in_reply_to
      new_mail.references  = mail.references  if mail.references

      if (@enable_html_mail || !mail.html_part)
        new_mail.content_type = mail.content_type
        new_mail.content_transfer_encoding = mail.content_transfer_encoding
        mail_head = new_mail.to_s.sub(/\r\n\r\n.*\z/m, "\r\n\r\n")
        mail_body = mail.raw_source.gsub(/(\r\n|\n|\r)/, "\r\n").sub(/\A.*?\r\n\r\n/m, "")
        return Mail.read_from_string(mail_head + mail_body)
      end

      body_text = mail.body ? mail.body.decoded.to_s : ""
      if mail.charset && !mail.charset.match(/utf-?8/i) && !mail.text_part
        body_text.force_encoding(mail.charset)
        body_text.encode!("utf-8")
      end
      body_text = mail.text_part.decoded.to_s if mail.text_part
      html_text = mail.html_part && mail.html_part.decoded.to_s
      new_mail.text_part = Mail::Part.new { body body_text }
      new_mail.html_part = Mail::Part.new { body html_text } if @enable_html_mail && html_text
      if mail.has_attachments?
        mail.attachments.each do |attachment|
          attachment_filename = attachment.filename.to_s
          if File.extname(attachment_filename).empty?
            ext = case attachment.mime_type.to_s.downcase
            when "text/plain"
              ".txt"
            when "application/pdf"
              ".pdf"
            when "application/rtf"
              ".rtf"
            when "application/msword"
              ".doc"
            when "application/vnd.ms-excel"
              ".xls"
            when "application/vnd.ms-powerpoint"
              ".ppt"
            when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
              ".docx"
            when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              ".xlsx"
            when "application/vnd.openxmlformats-officedocument.presentationml.presentation"
              ".pptx"
            when "application/x-js-taro"
              ".jtd"
            when "image/gif"
              ".gif"
            when "image/jpeg"
              ".jpeg"
            when "image/png"
              ".png"
            when "application/x-zip-compressed", "application/zip"
              ".zip"
            else
              ""
            end
            attachment_filename += ext
          end
          new_mail.attachments[attachment_filename] = attachment.decoded
        end
      end
      return new_mail
    end

    def create_check_code()
      return SecureRandom.base64(9)
    end

    def mail_filename(mail)
      Time.now.strftime("%Y%m%d-%H%M") +
      "-#{Digest::SHA512.hexdigest(mail.to_s)[0,16]}.eml"
    end

    def render_text(text, render_options)
      render_options.empty? ? text : Liquid::Template.parse(text).render(render_options)
    end

    def move_mail_file(filename, dir)
      new_filename = File.join(@maillogs_dir, dir, File.basename(filename))
      File.rename(filename, new_filename)
    end

    def error_message(error)
      "#{error.inspect} #{error.backtrace.first}"
    end
  end
end
