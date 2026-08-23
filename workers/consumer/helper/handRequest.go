package helper

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	"github.com/atharvyadav96k/notification-system/workers/consumer/applayer"
	amqp "github.com/rabbitmq/amqp091-go"
)

var conn *amqp.Connection

const (
	QueueName = "notification"
	BatchSize = 10
)

func init() {
	var err error

	rabbitURL := os.Getenv("RABBITMQ_URL")

	log.Printf("RABBITMQ_URL = [%s]", rabbitURL)

	if rabbitURL == "" {
		log.Fatal("RABBITMQ_URL is not set")
	}

	log.Printf("Connecting to RabbitMQ: %s", rabbitURL)

	conn, err = amqp.Dial(rabbitURL)
	if err != nil {
		log.Fatal(err)
	}

	ch, err := conn.Channel()
	if err != nil {
		log.Fatal(err)
	}

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
		log.Printf("Failed to create channel: %v", err)
		return
	}
	defer ch.Close()

	err = ch.Qos(
		BatchSize,
		0,
		false,
	)
	if err != nil {
		log.Printf("Failed to set QoS: %v", err)
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

	log.Printf("Worker started: %s", queue)

	for {

		batch := make(
			[]amqp.Delivery,
			0,
			BatchSize,
		)
		for len(batch) < BatchSize {

			msg, ok := <-messages

			if !ok {
				log.Printf("RabbitMQ consumer closed")
				return
			}

			batch = append(batch, msg)

			log.Printf(
				"Received message %d/%d",
				len(batch),
				BatchSize,
			)
		}
		processBatch(batch)
	}
}

func processBatch(batch []amqp.Delivery) {
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

	var successful int64
	var failed int64
	var failedToACK int64

	for _, msg := range batch {

		wg.Add(1)

		go func(msg amqp.Delivery) {
			defer wg.Done()

			err := processNotification(
				context.Background(),
				msg.Body,
			)

			if err != nil {
				atomic.AddInt64(&failed, 1)
				if nackErr := msg.Nack(false, true); nackErr != nil {
					atomic.AddInt64(&failedToACK, 1)
				}
				return
			}

			if err := msg.Ack(false); err != nil {
				atomic.AddInt64(&failedToACK, 1)
				return
			}

			atomic.AddInt64(&successful, 1)

		}(msg)
	}
	wg.Wait()
	fmt.Printf(
		"Successful: %d, Failed: %d, Failed to ACK: %d\n",
		successful,
		failed,
		failedToACK,
	)
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
	select {

	case <-time.After(200 * time.Millisecond):

	case <-ctx.Done():
		return ctx.Err()
	}
	return nil
}
