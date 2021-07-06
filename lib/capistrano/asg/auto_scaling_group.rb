module Capistrano
  module Asg
    # Extends AWS::AutoScaling::AutoScalingGroup to include some
    # convenience methods
    class AutoScalingGroup < SimpleDelegator
      def pause
        cache_current_group_sizes
        update(
          max_size: starting_size,
          min_size: starting_size,
          desired_capacity: starting_size
        )
      end

      def resume
        update(
          max_size: cached_max_size,
          min_size: cached_min_size,
          desired_capacity: cached_desired_capacity
        )
      end

      private

      attr_reader :original_aws_autoscaling_group
      attr_reader :cached_min_size, :cached_max_size, :cached_desired_capacity

      def starting_size
        @starting_size ||= health_instances.size
      end

      def cache_current_group_sizes
        @cached_max_size = max_size
        @cached_min_size = min_size
        @cached_desired_capacity = desired_capacity
      end

      def health_instances
        instances.select do |asg_instance|
          asg_instance.health_status == 'Healthy'
        end
      end
    end
  end
end
