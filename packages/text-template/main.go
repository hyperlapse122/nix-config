// Command text-template renders one Go text/template with a JSON document as
// its data and writes the result to stdout.
//
//	text-template <template> <data.json>
//
// The template can read only that document: no functions beyond Go's
// builtins are defined, so a gomplate-style env, file, or http call fails at
// parse time. A missing key fails execution, and so does printing a null,
// which Go renders as "<no value>" or, through print and printf, "<nil>".
// Nothing reaches stdout unless the whole render succeeds.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"text/template"
)

// Printed nulls, which missingkey=error does not catch.
var nullMarkers = []string{"<no value>", "<nil>"}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "text-template:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("usage: text-template <template> <data.json>")
	}
	templatePath, dataPath := args[0], args[1]

	source, err := os.ReadFile(templatePath)
	if err != nil {
		return err
	}
	raw, err := os.ReadFile(dataPath)
	if err != nil {
		return err
	}
	// Maps, not structs: missingkey applies only to map lookups.
	var data map[string]any
	if err := json.Unmarshal(raw, &data); err != nil {
		return fmt.Errorf("%s: %w", dataPath, err)
	}

	tmpl, err := template.New(filepath.Base(templatePath)).Option("missingkey=error").Parse(string(source))
	if err != nil {
		return err
	}
	var out bytes.Buffer
	if err := tmpl.Execute(&out, data); err != nil {
		return err
	}
	for _, marker := range nullMarkers {
		if bytes.Contains(out.Bytes(), []byte(marker)) {
			return fmt.Errorf("%s: output contains %q, a printed null value", templatePath, marker)
		}
	}
	_, err = os.Stdout.Write(out.Bytes())
	return err
}
