module Capistrano
  module Asg
    module Aws
      # Provide launch template read/write operations
      module LaunchTemplate
        extend ActiveSupport::Concern
        include Credentials
        include Region
        include Capistrano::DSL

        ##
        # returns: AWS::EC2::Types::CreateLaunchTemplateVersionResult
        def create_create_launch_template_version(image_id:, launch_template_id:)
          ec2_client.create_launch_template_version(
            launch_template_data: {
              image_id: image_id
            },
            source_version: lastest_launch_template_version(launch_template_id),
            launch_template_id: launch_template_id
          )
        end

        private

        def ec2_client
          ::Aws::EC2::Client.new(region: region, credentials: credentials)
        end

        def lastest_launch_template_version(launch_template_id)
          launch_template = describe_launch_template(launch_template_id)

          launch_template&.latest_version_number.to_s
        end

        ##
        # Describe the launch template by id
        # returns +Aws::EC2::Types::LaunchTemplate+
        def describe_launch_template(launch_template_id)
          result = ec2_client.describe_launch_templates(
            launch_template_ids: [launch_template_id]
          )
          return if result.launch_templates.nil? ||
                    result.launch_templates.empty?

          result.launch_templates.first
        end
      end
    end
  end
end
