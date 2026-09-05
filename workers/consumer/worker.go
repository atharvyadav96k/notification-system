package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

type Message struct {
	Message         string
	MessageType     int
	ReceiverAddress string
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	queueURL := os.Getenv("SQS_QUEUE_URL")
	if queueURL == "" {
		log.Fatal("SQS_QUEUE_URL environment variable is required")
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("failed to load AWS config: %v", err)
	}
	client := sqs.NewFromConfig(cfg)

	log.Println("worker started, polling SQS...")

	for {
		out, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     10,
		})
		if err != nil {
			if errors.Is(err, context.Canceled) {
				log.Println("shutting down, stopped polling SQS")
				return
			}
			log.Printf("receive message error: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		for _, msg := range out.Messages {
			var notification Message
			if err := json.Unmarshal([]byte(aws.ToString(msg.Body)), &notification); err != nil {
				log.Printf("failed to parse message, leaving in queue: %v", err)
				continue
			}

			if notification.Message == "" || notification.ReceiverAddress == "" {
				log.Printf("message missing required fields, leaving in queue: %s", aws.ToString(msg.Body))
				continue
			}

			log.Printf("received notification for %s: %s", notification.ReceiverAddress, notification.Message)

			_, err = client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueURL),
				ReceiptHandle: msg.ReceiptHandle,
			})
			if err != nil {
				log.Printf("failed to delete message: %v", err)
			}
		}
	}
}
