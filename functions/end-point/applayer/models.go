package applayer

type MessageTypes int

const (
	OTP       MessageTypes = 0
	Order     MessageTypes = 1
	Marketing MessageTypes = 2
)

type Priority string

const (
	PriorityHigh   Priority = "high"
	PriorityMedium Priority = "medium"
	PriorityLow    Priority = "low"
)

// Priority maps a message type to the queue priority it should be sent to:
// OTP is time-sensitive (user is actively waiting), Order is transactional but
// not real-time, Marketing is fully delay-tolerant and should never compete
// with OTP/Order for worker capacity.
func (m MessageTypes) Priority() Priority {
	switch m {
	case OTP:
		return PriorityHigh
	case Order:
		return PriorityMedium
	case Marketing:
		return PriorityLow
	default:
		return PriorityLow
	}
}

type Message struct {
	Message         string
	MessageType     MessageTypes
	ReceiverAddress string
}
