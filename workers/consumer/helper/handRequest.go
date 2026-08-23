package helper

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/atharvyadav96k/notification-system/workers/consumer/applayer"
	amqp "github.com/rabbitmq/amqp091-go"
)

var conn *amqp.Connection
var ch *amqp.Channel

func init() {
	var err error
	conn, err = amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatal(err)
	}

	ch, err = conn.Channel()
	if err != nil {
		log.Fatal(err)
	}

	queues := []string{"HIGH", "MEDIUM", "LOW"}

	for _, queue := range queues {
		_, err := ch.QueueDeclare(
			queue,
			true,
			false,
			false,
			false,
			nil,
		)

		if err != nil {
			log.Fatal(err)
		}
	}
}

func ConsumeNotification(queue string) {
	messages, err := ch.Consume(
		queue,
		"",
		false,
		false,
		false,
		false,
		nil,
	)

	if err != nil {
		log.Printf(
			"Failed to consume notification %s: %v",
			queue,
			err,
		)
		return
	}

	log.Printf("Worker started for queue: %s", queue)

	for msg := range messages {

		log.Printf(
			"[%s] Received: %s",
			queue,
			string(msg.Body),
		)

		err := processNotification(
			context.Background(),
			msg.Body,
		)

		if err != nil {
			log.Printf(
				"[%s] Failed to process: %v",
				queue,
				err,
			)
			continue
		}

		if err := msg.Ack(false); err != nil {
			log.Printf(
				"[%s] Failed to ACK: %v",
				queue,
				err,
			)
			continue
		}

		log.Printf(
			"[%s] Notification processed successfully",
			queue,
		)
	}
}

func processNotification(ctx context.Context, msg []byte) error {
	var notification applayer.Message

	if err := json.Unmarshal(msg, &notification); err != nil {
		return err
	}

	select {
	case <-time.After(0 * time.Millisecond):

	case <-ctx.Done():
		return ctx.Err()
	}
	return nil
}
