package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEKSClusterName(t *testing.T) {
	opts := &terraform.Options{
		TerraformDir: "/infra",
	}
	terraform.InitAndApply(t, opts)
	want := "example-app-cluster"
	got := terraform.Output(t, opts, "cluster_name")
	assert.Equal(t, want, got)
	terraform.Destroy(t, opts)
}
