package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

type Response struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

func sendOK(w http.ResponseWriter, r *http.Request) {
	if os.Getenv("DISABLE_CORS_THIS_IS_UNSAFE") == "true" {
		fmt.Fprint(os.Stdout, "WARNING: Disabling CORS to backend running on localhost\n")
		w.Header().Set("Access-Control-Allow-Origin", "http://localhost:8080")
		w.Header().Set("Vary", "Origin")
	}
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
