package main

import (
	"io"
	"net/http"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRealFrontendWorks(t *testing.T) {
	if os.Getenv("INTEGRATION") != "true" {
		t.Skip("skipping integration test")
	}
	if os.Getenv("FRONTEND_URL") == "" {
		t.Error("FRONTEND_URL needs to be defined")
	}
	resp, err := http.Get(os.Getenv("FRONTEND_URL"))
	require.NoError(t, err)
	assert.Equal(t, resp.StatusCode, 200)
	defer resp.Body.Close()
	got, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	assert.Contains(t, string(got), "Click the button below")
}
func TestRealBackendWorks(t *testing.T) {
	resp, err := http.Get(os.Getenv("BACKEND_URL"))
	require.NoError(t, err)
	assert.Equal(t, resp.StatusCode, 200)
	defer resp.Body.Close()
	want := `{"status":"ok","message":"Hello from the backend!"}`
	got, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	assert.Equal(t, want, string(got))
}
