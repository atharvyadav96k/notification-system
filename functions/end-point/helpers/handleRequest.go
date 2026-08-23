package helpers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/atharvyadav96k/notification-system/function/end-point/applayer"
	amqp "github.com/rabbitmq/amqp091-go"
)

var conn *amqp.Connection
var ch *amqp.Channel

const queueName = "notification"

func init() {
	// queue connection
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
	_, err := json.Marshal(notification)
	if err != nil {
		return err
	}
	return nil
}

func publishMessageToRabbitMQ(PRIORITY string, message []byte) error {
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
