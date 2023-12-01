package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

type Response struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

func sendOK(w http.ResponseWriter, r *http.Request) {
	b, _ := json.Marshal(&Response{
		Status:  "ok",
		Message: "Hello from the backend!",
	})
	fmt.Fprint(w, string(b))
}

func main() {
	http.HandleFunc("/", sendOK)
	http.ListenAndServe("0.0.0.0:8080", nil)
}
