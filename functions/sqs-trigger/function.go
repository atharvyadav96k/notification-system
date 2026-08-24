package main

import (
	"github.com/atharvyadav96k/notification-system/function/sqs-trigger/helpers"
	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	lambda.Start(helpers.Trigger())
}
