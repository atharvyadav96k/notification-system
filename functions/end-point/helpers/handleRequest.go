package helpers

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/atharvyadav96k/notification-system/function/end-point/applayer"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

var sqsClient *sqs.Client
var queueURLs map[applayer.Priority]string

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(err)
	}
	sqsClient = sqs.NewFromConfig(cfg)
	queueURLs = map[applayer.Priority]string{
		applayer.PriorityHigh:   os.Getenv("SQS_QUEUE_URL_HIGH"),
		applayer.PriorityMedium: os.Getenv("SQS_QUEUE_URL_MEDIUM"),
		applayer.PriorityLow:    os.Getenv("SQS_QUEUE_URL_LOW"),
	}
}

func SendNotification(ctx context.Context, event json.RawMessage) error {
	var notification applayer.Message
	if err := json.Unmarshal(event, &notification); err != nil {
		return err
	}
	return putMessageInTheQueue(ctx, notification)
}

func putMessageInTheQueue(ctx context.Context, notification applayer.Message) error {
	queueURL, ok := queueURLs[notification.MessageType.Priority()]
	if !ok || queueURL == "" {
		return fmt.Errorf("no queue configured for priority %q", notification.MessageType.Priority())
	}

	body, err := json.Marshal(notification)
	if err != nil {
		return err
	}

	_, err = sqsClient.SendMessage(ctx, &sqs.SendMessageInput{
		QueueUrl:    aws.String(queueURL),
		MessageBody: aws.String(string(body)),
	})
	return err
}
