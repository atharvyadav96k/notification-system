package helpers

import (
	"context"
	"encoding/json"
	"os"

	"github.com/atharvyadav96k/notification-system/function/end-point/applayer"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

var sqsClient *sqs.Client
var queueURL string

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(err)
	}
	sqsClient = sqs.NewFromConfig(cfg)
	queueURL = os.Getenv("SQS_QUEUE_URL")
}

func SendNotification(ctx context.Context, event json.RawMessage) error {
	var notification applayer.Message
	if err := json.Unmarshal(event, &notification); err != nil {
		return err
	}
	return putMessageInTheQueue(ctx, notification)
}

func putMessageInTheQueue(ctx context.Context, notification applayer.Message) error {
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
