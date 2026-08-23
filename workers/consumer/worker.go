package main

import "github.com/atharvyadav96k/notification-system/workers/consumer/helper"

func main() {
	for i := 0; i < 10; i++ {
		go helper.ConsumeNotification("notification")
	}
	select {}
}
