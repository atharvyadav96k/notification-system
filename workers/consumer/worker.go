package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
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
	ctx := context.Background()

	queueURL := os.Getenv("SQS_QUEUE_URL")
	if queueURL == "" {
		log.Fatal("SQS_QUEUE_URL environment variable is required")
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("failed to load AWS config: %v", err)
	}
	client := sqs.NewFromConfig(cfg)

	logFile, err := os.OpenFile("/home/ec2-user/notifications_received.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("failed to open log file: %v", err)
	}
	defer logFile.Close()

	log.Println("worker started, polling SQS...")

	for {
		out, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     10,
		})
		if err != nil {
			log.Printf("receive message error: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		for _, msg := range out.Messages {
			var notification Message
			if err := json.Unmarshal([]byte(aws.ToString(msg.Body)), &notification); err != nil {
				log.Printf("failed to parse message: %v", err)
				continue
			}

			entry := fmt.Sprintf("[%s] received notification for %s: %s\n",
				time.Now().Format(time.RFC3339), notification.ReceiverAddress, notification.Message)

			if _, err := logFile.WriteString(entry); err != nil {
				log.Printf("failed to write log entry: %v", err)
				continue
			}

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
