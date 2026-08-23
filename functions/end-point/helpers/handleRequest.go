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

const queueName = "notification"

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

	_, err = ch.QueueDeclare(
		queueName,
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
	return publishMessage(queueName, message)
}

func publishMessage(PRIORITY string, message []byte) error {
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
