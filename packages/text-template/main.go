// Command text-template renders one Go text/template with a JSON document as
// its data and writes the result to stdout.
//
//	text-template <template> <data.json>
//
// The template can read only that document: no functions beyond Go's
// builtins are defined, so a gomplate-style env, file, or http call fails at
// parse time. A missing key fails execution, whether read through a field or
// through index, and so does printing a null, which Go renders as
// "<no value>" or, through print and printf, "<nil>". Nothing reaches stdout
// unless the whole render succeeds.
package main

import (
	"bytes"
	"encoding/json"
	"errors"
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
		return errors.New("usage: text-template <template> <data.json>")
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

	tmpl, err := template.New(filepath.Base(templatePath)).
		Option("missingkey=error").
		Funcs(template.FuncMap{"index": strictIndex}).
		Parse(string(source))
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

// strictIndex replaces the builtin index, which returns the zero value for a
// missing map key whatever missingkey says, so a missing fact read in an `if`
// would render the false branch instead of failing.
func strictIndex(item any, keys ...any) (any, error) {
	for _, key := range keys {
		switch collection := item.(type) {
		case map[string]any:
			name, ok := key.(string)
			if !ok {
				return nil, fmt.Errorf("index: map key %v is not a string", key)
			}
			value, ok := collection[name]
			if !ok {
				return nil, fmt.Errorf("index: map has no entry for key %q", name)
			}
			item = value
		case []any:
			position, ok := key.(int)
			if !ok || position < 0 || position >= len(collection) {
				return nil, fmt.Errorf("index: %v is out of range for a list of %d", key, len(collection))
			}
			item = collection[position]
		default:
			return nil, fmt.Errorf("index: cannot index %T", item)
		}
	}
	return item, nil
}
