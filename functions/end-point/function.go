package main

import (
	"context"
	"encoding/json"
	"math/rand"

	"github.com/atharvyadav96k/notification-system/function/end-point/helpers"
	"github.com/aws/aws-lambda-go/lambda"
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
	aws := false

	if aws {
		lambda.Start(helpers.SendNotification)
	} else {
		for i := 0; i < 1000000; i++ {

			notification := notifications[rand.Intn(len(notifications))]

			event := json.RawMessage(notification)

			helpers.SendNotification(context.Background(), event)
		}
	}
}
