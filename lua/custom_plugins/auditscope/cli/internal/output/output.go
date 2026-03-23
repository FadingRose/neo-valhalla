package output

import (
	"encoding/json"
	"fmt"
	"os"
)

type Status string

const (
	StatusSuccess Status = "success"
	StatusError   Status = "error"
)

type Response struct {
	Status    Status `json:"status"`
	Operation string `json:"operation"`
	Message   string `json:"message,omitempty"`
	Data      any    `json:"data,omitempty"`
	Error     string `json:"error,omitempty"`
	Hint      string `json:"hint,omitempty"`
}

func Success(operation, message string, data any) Response {
	return Response{
		Status:    StatusSuccess,
		Operation: operation,
		Message:   message,
		Data:      data,
	}
}

func Error(operation, errMsg string, hint string) Response {
	return Response{
		Status:    StatusError,
		Operation: operation,
		Error:     errMsg,
		Hint:      hint,
	}
}

func (r Response) Print() {
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, `{"status":"error","error":"failed to marshal response"}`)
		return
	}
	fmt.Println(string(data))
}

func PrintSuccess(operation, message string, data any) {
	Success(operation, message, data).Print()
}

func PrintError(operation, errMsg string, hint string) {
	Error(operation, errMsg, hint).Print()
}

func PrintRaw(data any) {
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, `{"status":"error","error":"failed to marshal data"}`)
		return
	}
	fmt.Println(string(jsonData))
}
