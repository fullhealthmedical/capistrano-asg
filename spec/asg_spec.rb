describe 'Capistrano::Asg' do
  before do
    allow_any_instance_of(Capistrano::Asg::AWSResource).to receive(:autoscaling_group_name) { 'production' }
    webmock :get, /security-credentials/ => 'security-credentials.200.json'
    webmock(:post, %r{autoscaling.(.*).amazonaws.com\/\z} => 'DescribeAutoScalingGroups.200.xml') { Hash[body: /Action=DescribeAutoScalingGroups/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'DescribeImages.200.xml') { Hash[body: /Action=DescribeImages/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'DescribeTags.200.xml') { Hash[body: /Action=DescribeTags/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'DescribeInstances.200.xml') { Hash[body: /Action=DescribeInstances/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'CreateImage.200.xml') { Hash[body: /Action=CreateImage/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'DeregisterImage.200.xml') { Hash[body: /Action=DeregisterImage/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'CreateTags.200.xml') { Hash[body: /Action=CreateTags/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'DescribeSnapshots.200.xml') { Hash[body: /Action=DescribeSnapshots/] }
    webmock(:post, %r{ec2.(.*).amazonaws.com\/\z} => 'DeleteSnapshot.200.xml') { Hash[body: /Action=DeleteSnapshot/] }
    webmock(:post, %r{autoscaling.(.*).amazonaws.com\/\z} => 'DescribeLaunchConfigurations.200.xml') { Hash[body: /Action=DescribeLaunchConfigurations/] }
    webmock(:post, %r{autoscaling.(.*).amazonaws.com\/\z} => 'CreateLaunchConfiguration.200.xml') { Hash[body: /Action=CreateLaunchConfiguration/] }
    webmock(:post, %r{autoscaling.(.*).amazonaws.com\/\z} => 'DeleteLaunchConfiguration.200.xml') { Hash[body: /Action=DeleteLaunchConfiguration/] }
    webmock(:post, %r{autoscaling.(.*).amazonaws.com\/\z} => 'UpdateAutoScalingGroup.200.xml') { Hash[body: /Action=UpdateAutoScalingGroup/] }

    set :aws_region, 'eu-west-1'
    set :aws_secret_access_key, 'key'
    set :aws_access_key_id, 'id'
  end

  let!(:ami) do
    _ami = nil
    Capistrano::Asg::AMI.create { |ami| _ami = ami }
    _ami
  end

  describe 'AMI creation & cleanup' do
    it 'creates a new AMI on Amazon' do
      expect(ami.aws_counterpart.id).to eq 'ami-4fa54026'
    end

    it 'deletes any AMIs tagged with deployed-with=cap-asg' do
      expect(WebMock).to have_requested(:post, /ec2.(.*).amazonaws.com\/\z/).with(body: /Action=DeregisterImage&ImageId=ami-1a2b3c4d/)
    end

    it 'deletes snapshots that are associated with the AMI' do
      expect(WebMock).to have_requested(:post, /ec2.(.*).amazonaws.com\/\z/).with(body: /Action=DeleteSnapshot&SnapshotId=snap-1a2b3c4d/)
    end

    it 'tags the new AMI with deployed-with=cap-asg' do
      expect(WebMock).to have_requested(:post, /ec2.(.*).amazonaws.com\/\z/).with(body: /Action=CreateTags&ResourceId.1=ami-4fa54026&Tag.1.Key=deployed-with&Tag.1.Value=cap-asg/)
    end

    it 'tags the new AMI with cap-asg-Deploy-group=<autoscale group name>' do
      expect(WebMock).to have_requested(:post, /ec2.(.*).amazonaws.com\/\z/).with(body: /Action=CreateTags&ResourceId.1=ami-4fa54026&Tag.1.Key=cap-asg-deploy-group&Tag.1.Value=production/)
    end
  end

  describe 'Launch configuration creation & cleanup' do
    let!(:launch_configuration) do
      _lc = nil
      Capistrano::Asg::LaunchConfiguration.create(ami) { |lc| _lc = lc }
      _lc
    end

    it 'creates a new Launch Configuration on AWS' do
      expect(WebMock).to have_requested(:post, /autoscaling.(.*).amazonaws.com\/\z/).
        with(body: /Action=CreateLaunchConfiguration&AssociatePublicIpAddress=true&IamInstanceProfile=arn%3Aaws%3Aiam%3A%3A123456789012%3Ainstance-profile%2FAdminRole&ImageId=ami-4fa54026&InstanceMonitoring.Enabled=true&InstanceType=m1.small&LaunchConfigurationName=cap-asg-production/)
    end

    it 'deletes any LCs with name =~ cap-asg-production' do
      expect(WebMock).to have_requested(:post, /autoscaling.(.*).amazonaws.com\/\z/).with(body: /Action=DeleteLaunchConfiguration&LaunchConfigurationName=cap-asg-production-production-lc-1234567890/)
    end

    it 'attaches the LC to the autoscale group' do
      launch_configuration.attach_to_autoscale_group!
      expect(WebMock).to have_requested(:post, /autoscaling.(.*).amazonaws.com\/\z/).with(body: /Action=UpdateAutoScalingGroup&AutoScalingGroupName=production&LaunchConfigurationName=cap-asg-production-production-lc-\d{10,}/)
    end
  end
end
