package main

import (
	"bytes"
	"errors"
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
	if os.Getenv("BACKEND_URL") == "" {
		return "", errors.New("Please define BACKEND_URL in the environment")
	}
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
				resultDiv.innerHTML = "<p>Backend is up! Message: " + xhr.responseText;
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
		fmt.Fprint(w, html)
	}
}
