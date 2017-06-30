# frozen_string_literal: true
gem 'nex_client', '~> 0.16.0'
require 'nex_client'

module MnoEnterprise
  module PlatformAdapters
    # Nex!™ Adapter for MnoEnterprise::PlatformClient
    # The Nex!™ docker image provide `awscli` and a Minio storage addon
    class NexAdapter < Adapter
      class << self

        # @see MnoEnterprise::PlatformAdapters::Adapter#restart
        def restart
          # TODO: implement using nex_client
          # For now this work with one node
          # SELF_NEX_API_KEY="some-api-key"
          # SELF_NEX_API_ENDPOINT="https://api-nex-uat.maestrano.io"
          FileUtils.touch('tmp/restart.txt')
        end

        # @see MnoEnterprise::PlatformAdapters::Adapter#publish_assets
        def publish_assets
          sync_assets(public_folder, 's3://${MINIO_BUCKET}/public/', '--delete')
          sync_assets(frontend_folder, 's3://${MINIO_BUCKET}/frontend/', '--delete')
          copy_asset(logo_file, 's3://${MINIO_BUCKET}/assets/main-logo.png')
        end

        # @see MnoEnterprise::PlatformAdapters::Adapter#fetch_assets
        # Using `--exact-timestamps` to sync assets from S3 when they have the same size
        def fetch_assets
          sync_assets('s3://${MINIO_BUCKET}/public/', public_folder, '--delete --exact-timestamps')
          sync_assets('s3://${MINIO_BUCKET}/frontend/', frontend_folder, '--delete --exact-timestamps')
          copy_asset('s3://${MINIO_BUCKET}/assets/main-logo.png', logo_file)
        end

        private

        def public_folder
          @public_folder ||= Rails.root.join('public')
        end

        def frontend_folder
          @frontend_folder ||= Rails.root.join('frontend', 'src')
        end

        def logo_file
          @logo_file ||= Rails.root.join('app', 'assets', 'images', 'mno_enterprise', 'main-logo.png')
        end

        def aws_auth
          @aws_auth ||= 'AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY} AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}'
        end

        def aws_cli
          @aws_cli ||= "#{aws_auth} aws --endpoint-url ${MINIO_URL}"
        end

        # Syncs directories and S3 prefixes.
        # Recursively copies new and updated files from the source directory to the destination.
        #
        # @param [Object] src
        # @param [Object] dst
        # @param [String] options options to pass to the aws cli
        # @return [boolean] `true` if the operation was successful
        def sync_assets(src, dst, options=nil)
          if ENV['MINIO_URL'] && ENV['MINIO_BUCKET']
            args = [src, dst, options].compact.join(' ')
            %x(#{aws_cli} s3 sync #{args})
          end
          $?.exitstatus == 0
        end

        # Copies a local file or S3 object to another location locally or in S3.
        def copy_asset(src, dst, options=nil)
          if ENV['MINIO_URL'] && ENV['MINIO_BUCKET']
            args = [src, dst, options].compact.join(' ')
            %x(#{aws_cli} s3 cp #{args})
          end
          $?.exitstatus == 0
        end
      end
    end
  end
end
