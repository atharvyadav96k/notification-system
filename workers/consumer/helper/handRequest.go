package helper

import (
	"context"
	"encoding/json"
	"log"
	"sort"
	"sync"
	"time"

	"github.com/atharvyadav96k/notification-system/workers/consumer/applayer"
	amqp "github.com/rabbitmq/amqp091-go"
)

var conn *amqp.Connection

const (
	QueueName = "notifications"
	BatchSize = 10
)

func init() {
	var err error

	conn, err = amqp.Dial(
		"amqp://guest:guest@localhost:5672/",
	)
	if err != nil {
		log.Fatal(err)
	}

	ch, err := conn.Channel()
	if err != nil {
		log.Fatal(err)
	}
	defer ch.Close()

	_, err = ch.QueueDeclare(
		QueueName,
		true,
		false,
		false,
		false,
		nil,
	)

	if err != nil {
		log.Fatal(err)
	}

	log.Printf("RabbitMQ queue ready: %s", QueueName)
}

func ConsumeNotification(queue string) {

	ch, err := conn.Channel()
	if err != nil {
		log.Printf(
			"Failed to create channel: %v",
			err,
		)
		return
	}
	defer ch.Close()
	err = ch.Qos(
		BatchSize,
		0,
		false,
	)
	if err != nil {
		log.Printf(
			"Failed to set QoS: %v",
			err,
		)
		return
	}

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
			"Failed to consume %s: %v",
			queue,
			err,
		)
		return
	}

	log.Printf(
		"Worker started: %s",
		queue,
	)

	for {

		batch := make(
			[]amqp.Delivery,
			0,
			BatchSize,
		)
		for len(batch) < BatchSize {

			msg, ok := <-messages

			if !ok {
				log.Printf(
					"RabbitMQ consumer closed",
				)
				return
			}

			batch = append(
				batch,
				msg,
			)

			log.Printf(
				"Message received: %d/%d",
				len(batch),
				BatchSize,
			)
		}
		processBatch(batch)
	}
}

func processBatch(batch []amqp.Delivery) {

	log.Printf(
		"Processing batch of %d messages",
		len(batch),
	)

	sort.SliceStable(
		batch,
		func(i, j int) bool {

			var messageI applayer.Message
			var messageJ applayer.Message

			if err := json.Unmarshal(batch[i].Body, &messageI); err != nil {
				return false
			}

			if err := json.Unmarshal(batch[j].Body, &messageJ); err != nil {
				return false
			}

			return messageI.MessageType < messageJ.MessageType
		},
	)

	var wg sync.WaitGroup

	for _, msg := range batch {

		wg.Add(1)

		go func(msg amqp.Delivery) {
			defer wg.Done()

			err := processNotification(
				context.Background(),
				msg.Body,
			)

			if err != nil {
				log.Printf(
					"Failed to process: %v",
					err,
				)
				return
			}

			if err := msg.Ack(false); err != nil {
				log.Printf(
					"Failed to ACK: %v",
					err,
				)
				return
			}

			log.Println("Notification processed successfully")

		}(msg)
	}
	wg.Wait()
}

func processNotification(
	ctx context.Context,
	msg []byte,
) error {

	var notification applayer.Message

	if err := json.Unmarshal(
		msg,
		&notification,
	); err != nil {
		return err
	}

	log.Printf(
		"Processing notification: type=%d receiver=%s",
		notification.MessageType,
		notification.ReceiverAddress,
	)
	select {

	case <-time.After(2 * time.Second):
		log.Printf(
			"Notification sent to %s",
			notification.ReceiverAddress,
		)

	case <-ctx.Done():
		return ctx.Err()
	}
	return nil
}
