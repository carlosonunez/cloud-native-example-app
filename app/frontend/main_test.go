package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIndexPageRenders(t *testing.T) {
	t.Setenv("BACKEND_URL", "foo.bar")
	html, err := indexPage()
	require.NoError(t, err)
	assert.Contains(t, html, "xhr.open('get', 'foo.bar')")
	assert.Contains(t, html, "<title>Hello, World</title>")
}

func TestWebsiteWorks(t *testing.T) {
	t.Setenv("BACKEND_URL", "foo.bar")
	want, _ := indexPage()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()
	renderIndex(w, req)
	res := w.Result()
	defer res.Body.Close()
	data, err := io.ReadAll(res.Body)
	require.NoError(t, err)
	assert.Equal(t, want, string(data))
}

func TestRealWebsiteWorks(t *testing.T) {
	if os.Getenv("INTEGRATION") != "true" {
		t.Skip("skipping integration test")
	}
	if os.Getenv("FRONTEND_URL") == "" {
		t.Error("FRONTEND_URL needs to be defined")
	}
}
