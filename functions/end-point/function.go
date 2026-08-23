package main

import (
	"github.com/atharvyadav96k/notification-system/function/end-point/helpers"
	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	lambda.Start(helpers.SendNotification)
}
