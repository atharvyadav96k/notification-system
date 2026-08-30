package helpers

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

func Trigger() error {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("failed to load AWS config: %w", err)
	}
	client := ec2.NewFromConfig(cfg)

	out, err := client.DescribeInstances(ctx, &ec2.DescribeInstancesInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("tag:Name"), Values: []string{"Worker"}},
			{Name: aws.String("instance-state-name"), Values: []string{"stopped", "stopping"}},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to describe worker instances: %w", err)
	}

	var instanceIDs []string
	for _, reservation := range out.Reservations {
		for _, instance := range reservation.Instances {
			instanceIDs = append(instanceIDs, aws.ToString(instance.InstanceId))
		}
	}

	if len(instanceIDs) == 0 {
		fmt.Println("worker instance already running, no action needed")
		return nil
	}

	_, err = client.StartInstances(ctx, &ec2.StartInstancesInput{
		InstanceIds: instanceIDs,
	})
	if err != nil {
		return fmt.Errorf("failed to start worker instance: %w", err)
	}

	fmt.Printf("started worker instance(s): %v\n", instanceIDs)
	return nil
}
