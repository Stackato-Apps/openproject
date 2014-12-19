class MigrateAttachmentsToCarrierWave < ActiveRecord::Migration
  def up
    add_column :attachments, :file, :string

    count = Attachment.count

    Rails.logger.info "Migrating #{count} attachments to CarrierWave."
    Rails.logger.warn 'Depending on your configuration this can take a while.
                       Especially if files are uploaded to S3.'

    Attachment.all.each_with_index do |attachment, i|
      Rails.logger.info "Migrating attachment #{i + 1}/#{count} (#{attachment.disk_filename})"
      migrate_attachment attachment
    end

    Rails.logger.info 'Attachment migration complete.'
  end

  def down
    count = Attachment.count

    Rails.logger.info "Rolling back #{count} attachments from CarrierWave to legacy file-based storage."
    Rails.logger.warn 'Depending on your configuration this can take a while.
                       Especially if files are downloaded from S3.'

    Attachment.all.each_with_index do |attachment, i|
      Rails.logger.info "Migrating attachment #{i + 1}/#{count} (#{attachment.file.path})"
      rollback_attachment attachment
    end

    remove_column :attachments, :file
  end

  ##
  # In the olden times (pre 4.1) files were all saved under the configured storage path,
  # most likely `files`, with a timestamp attached to their name to avoid conflicts.
  #
  # e.g. `files/140917231758_openshift-setup.txt`
  #
  # The new shit is using CarrierWave for attachments. There the files will be stored some place else.
  # Where is not material for this migration. It could be another directory or S3.
  #
  # The migration does the following:
  #
  # * rename the legacy files - it strips off the timestamps
  # * assign the renamed file to the CarrierWave uploader - this moves the file to the new location
  #
  # The rollback does the opposite using the remaining legacy column `disk_filename` of Attachment.
  # Meaning it adds the timestamp again and puts the files back into the configured attachment storage path.
  #
  # This assumes that the attachment storage path is the same as before the migration to CarrierWave
  # and also that the legacy columns `filename` and `disk_filename` are still present.
  module LegacyAttachment
    def migrate_attachment(attachment)
      file = legacy_file_name attachment.disk_filename
      new_file = strip_timestamp_from_filename(file)

      if File.readable? file
        FileUtils.move file, new_file
        attachment.file = File.open(new_file)
        attachment.save!
        attachment.update_column :filename, ''

        FileUtils.rm_f new_file

        File.readable? attachment.file.path
      else
        unless File.readable? attachment.file.path
          Rails.logger.warn "Found corrupt attachment during migration: #{attachment.inspect}"
          false
        else
          true # file has been migrated already
        end
      end
    end

    def rollback_attachment(attachment)
      return unless attachment.file.path

      old_file = rolled_back_file_name attachment

      unless File.readable? old_file
        file = attachment.file.path

        FileUtils.move file, old_file
        attachment.update_columns file: nil,
                                  filename: Pathname(file).basename.to_s,
                                  disk_filename: Pathname(old_file).basename.to_s
      end
    end

    ##
    # Returns rolled back file name for an attachment.
    # If an attachment was created after the migration to CarrierWave it doesn't have an original
    # legacy name. Instead one will be generated. Not with a timestamp, however, but with a
    # random hex string as a prefix.
    #
    # This way new attachments won't be lost when rolling back to an old version of OpenProject.
    def rolled_back_file_name(attachment)
      if attachment.disk_filename.blank?
        uuid = SecureRandom.hex 4
        name = Pathname(attachment.file.path).basename
        legacy_file_name "#{uuid}_#{name}"
      else
        attachment.disk_filename
      end
    end

    def legacy_file_name(file_name)
      Pathname(OpenProject::Configuration.attachment_storage_path).join file_name
    end

    ##
    # This method strips the leading timestamp from a given file name and returns the plain,
    # original file name.
    def strip_timestamp_from_filename(file)
      Pathname(file).dirname + Pathname(file).basename.to_s.gsub(/^[^_]+_/, '')
    end
  end

  include LegacyAttachment
end
