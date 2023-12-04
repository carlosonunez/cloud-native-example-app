package main

import (
	"bytes"
	"fmt"
	"html/template"
	"io"
	"net/http"
	"os"
)

type templateContext struct {
	Title      string
	BackendURL string
}

func indexPage() (string, error) {
	t, err := template.New("page").Parse(`<html>
<head>
	<title>{{ .Title }}</title>
</head>
<script>
function runTheCheck() {
	var resultDiv = document.getElementById("result");
	var xhr = new XMLHttpRequest();
	xhr.onreadystatechange = function() {
		var DONE = 4;
		if (xhr.readyState == DONE) {
			if (xhr.status == 200) {
				result = JSON.parse(xhr.responseText);
				resultDiv.innerHTML = "<p>Backend is up! Message: " + result.message;
			} else {
				resultDiv.innerHTML = "<p>Backend is not up.</p>";
			}
		}
	};
	xhr.open('get', '{{ .BackendURL }}');
	xhr.send();
};
</script>
<body>
	<div id="header">
		<p>Click the button below to check if we can talk to the backend.</p>
	</div>
	<button onclick="runTheCheck()">Click me!</button>
	<div id="result"></div>
</body>
</html>`)
	if err != nil {
		return "", err
	}
	tCxt := templateContext{
		Title:      "Hello, World",
		BackendURL: os.Getenv("BACKEND_URL"),
	}
	var b bytes.Buffer
	bw := io.Writer(&b)
	if err := t.Execute(bw, tCxt); err != nil {
		return "", err
	}
	return b.String(), nil
}

func renderIndex(w http.ResponseWriter, r *http.Request) {
	html, err := indexPage()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, err.Error())
	} else {
		fmt.Fprintf(os.Stderr, "Disabling CORS? %s\n", os.Getenv("DISABLE_CORS_THIS_IS_UNSAFE"))
		if os.Getenv("DISABLE_CORS_THIS_IS_UNSAFE") == "true" {
			fmt.Fprint(os.Stdout, "WARNING: Disabling CORS to backend running on localhost\n")
			w.Header().Set("Access-Control-Allow-Origin", "http://localhost:8081")
			w.Header().Set("Vary", "Origin")
		}
		fmt.Fprint(w, html)
	}
}

func main() {
	if os.Getenv("BACKEND_URL") == "" {
		fmt.Fprint(os.Stderr, "Please define BACKEND_URL in the environment")
		os.Exit(1)
	}
	http.HandleFunc("/", renderIndex)
	http.ListenAndServe("0.0.0.0:8080", nil)
}
