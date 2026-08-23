package helpers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/atharvyadav96k/notification-system/function/end-point/applayer"
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

func SendNotification(ctx context.Context, event json.RawMessage) error {
	var notification applayer.Message
	if err := json.Unmarshal(event, &notification); err != nil {
		return err
	}
	err := putMessageInTheQueue(notification)
	if err != nil {
		fmt.Println("Failed to send the message")
	}
	return nil
}

func putMessageInTheQueue(notification applayer.Message) error {
	message, err := json.Marshal(notification)
	if err != nil {
		return err
	}

	switch notification.MessageType {
	case applayer.OTP:
		return publishMessage("HIGH", message)

	case applayer.Order:
		return publishMessage("MEDIUM", message)

	case applayer.Marketing:
		return publishMessage("LOW", message)

	default:
		return fmt.Errorf("notification type not in scope: %v", notification.MessageType)
	}
}

func publishMessage(PRIORITY string, message []byte) error {
	fmt.Println(PRIORITY)
	return ch.Publish(
		"",
		PRIORITY,
		false,
		false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        message,
		},
	)
}
