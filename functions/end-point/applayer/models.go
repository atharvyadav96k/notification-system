package applayer

type MessageTypes int

const (
	OTP       MessageTypes = 0
	Order     MessageTypes = 1
	Marketing MessageTypes = 2
)

type Message struct {
	Message         string
	MessageType     MessageTypes
	ReceiverAddress string
}
