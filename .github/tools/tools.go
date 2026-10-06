//go:build tools

// Package tools lists the CI tools that the workflows build. Dependabot updates
// their versions in go.mod; it does not update Go tool directives
// (dependabot/dependabot-core#12050), so this file keeps them direct.
package tools

import (
	_ "github.com/rhysd/actionlint/cmd/actionlint"
	_ "github.com/zricethezav/gitleaks/v8"
)
