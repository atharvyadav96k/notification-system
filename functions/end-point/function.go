package main

import (
	"context"
	"encoding/json"
	"math/rand"
	"sync"
	"time"

	"github.com/atharvyadav96k/notification-system/function/end-point/helpers"
	"github.com/aws/aws-lambda-go/lambda"
)

const (
	totalRequests = 1_000_000
	duration      = time.Minute
)

var notifications = []string{
	`{
		"Message": "Your OTP is 123456",
		"MessageType": 0,
		"ReceiverAddress": "+919876543210"
	}`,
	`{
		"Message": "Your payment was successful",
		"MessageType": 1,
		"ReceiverAddress": "+919876543210"
	}`,
	`{
		"Message": "Redeem offer",
		"MessageType": 2,
		"ReceiverAddress": "+919876543210"
	}`,
}

func main() {
	aws := true

	if aws {
		lambda.Start(helpers.SendNotification)
	} else {
		interval := duration / time.Duration(totalRequests)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		var wg sync.WaitGroup

		for i := 0; i < totalRequests; i++ {
			<-ticker.C

			notification := notifications[rand.Intn(len(notifications))]
			event := json.RawMessage(notification)

			wg.Add(1)
			go func() {
				defer wg.Done()
				helpers.SendNotification(context.Background(), event)
			}()
		}

		wg.Wait()
	}
}
