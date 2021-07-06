require 'capistrano/asg'

namespace :asg do
  task :scale do
    set :aws_access_key_id,     fetch(:aws_access_key_id,     ENV['AWS_ACCESS_KEY_ID'])
    set :aws_secret_access_key, fetch(:aws_secret_access_key, ENV['AWS_SECRET_ACCESS_KEY'])
    asg_launch_config = {}
    asg_ami_id = {}

    # Iterate over relevant regions
    regions = fetch(:regions)
    regions.keys.each do |region|
      set :aws_region, region
      asg_launch_config[region] = {}
      asg_ami_id[region] = {}

      # Iterate over relevant ASGs
      regions[region].each do |asg|
        set :aws_autoscale_group_name, asg
        Capistrano::Asg::AMI.create do |ami|
          puts "Autoscaling: Created AMI: #{ami.aws_counterpart.id} from region #{region} in ASG #{asg}"

          launch_template_id = autoscaling_group.launch_template.launch_template_id

          result = create_create_launch_template_version(
            image_id: ami.aws_counterpart.id,
            launch_template_id: launch_template_id
          )

          puts "Autoscaling: Created version for #{result.launch_template_version.launch_template_name}"

          cached_asg = fetch(:autoscale_groups, {})[asg]

          if cached_asg
            cached_asg.resume
            puts "Autoscaling: Resumed #{asg} autoscaling"
          else
            puts "Autoscaling: Can't resume autoscaling for #{asg}"
          end
        end

        reset_autoscaling_objects
        reset_ec2_objects
      end
    end

    set :asg_launch_config, asg_launch_config
    set :asg_ami_id, asg_ami_id
  end
end
