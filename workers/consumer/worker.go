package main

import "github.com/atharvyadav96k/notification-system/workers/consumer/helper"

func main() {
	go helper.ConsumeNotification("HIGH")
	go helper.ConsumeNotification("MEDIUM")
	go helper.ConsumeNotification("LOW")

	select {}
}
