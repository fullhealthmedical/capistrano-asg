require 'aws-sdk-ec2'
require 'aws-sdk-autoscaling'
require 'capistrano/all'
require 'active_support/concern'

require 'capistrano/asg/version'
require 'capistrano/asg/retryable'
require 'capistrano/asg/taggable'
require 'capistrano/asg/logger'
require 'capistrano/asg/aws/credentials'
require 'capistrano/asg/aws/region'
require 'capistrano/asg/aws/autoscaling'
require 'capistrano/asg/aws/ec2'
require 'capistrano/asg/aws/launch_template'
require 'capistrano/asg/auto_scaling_group'
require 'capistrano/asg/aws_resource'
require 'capistrano/asg/ami'

module Capistrano
  module Asg
  end
end

require 'capistrano/dsl'

load File.expand_path('../asg/tasks/asg.rake', __FILE__)

def autoscale(groupname, *args)
  include Capistrano::DSL
  include Capistrano::Asg::Aws::AutoScaling
  include Capistrano::Asg::Aws::EC2
  include Capistrano::Asg::Aws::LaunchTemplate

  set :aws_autoscale_group, groupname

  autoscaling_group = autoscaling_resource.autoscaling_group
  asg_instances = autoscaling_group.instances

  region = fetch(:aws_region)
  regions = fetch(:regions, {})
  (regions[region] ||= []) << groupname
  set :regions, regions

  asg_instances.each do |asg_instance|
    if asg_instance.health_status != 'Healthy'
      puts "Autoscaling: Skipping unhealthy instance #{asg_instance.id}"
    else
      ec2_instance = ec2_resource.instance(asg_instance.id)
      hostname = ec2_instance.public_ip_address
      puts "Autoscaling: Adding server #{hostname}"
      server(hostname, *args)
    end
  end

  if asg_instances.count > 0 && fetch(:create_ami, true)
    after('deploy:finishing', 'asg:scale')
  else
    puts 'Autoscaling: AMI could not be created because no running instances were found.\
      Is your autoscale group name correct?'
  end

  reset_autoscaling_objects
  reset_ec2_objects
end
