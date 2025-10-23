package command

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Spec struct {
	Executable string   `json:"executable"`
	Arguments  []string `json:"arguments"`
	Stdin      *string  `json:"stdin"`
	Timeout    float64  `json:"timeout"`
}

type Result struct {
	ExitCode int    `json:"exit_code"`
	Output   string `json:"output"`
}

func New(input io.Reader) (Spec, error) {
	var spec Spec
	if err := json.NewDecoder(input).Decode(&spec); err != nil {
		return spec, err
	}

	if spec.Timeout == 0 {
		spec.Timeout = 1000
	}

	return spec, nil
}

func (spec Spec) Run(ctx context.Context, output io.Writer) error {
	ctx, cancel := context.WithTimeout(ctx,
		time.Duration(spec.Timeout)*time.Millisecond)
	defer cancel()

	var stderr, stdout strings.Builder
	command := exec.CommandContext(ctx, spec.Executable, spec.Arguments...)
	command.Stdout = &stdout
	command.Stderr = &stderr
	if spec.Stdin != nil && *spec.Stdin != "" {
		reader := strings.NewReader(*spec.Stdin)
		command.Stdin = reader
	}

	var result Result
	if err := command.Run(); err == nil {
		result.Output = stdout.String()
	} else if exit, ok := err.(*exec.ExitError); ok {
		result.ExitCode = exit.ExitCode()
		result.Output = stderr.String()
		fmt.Fprintln(os.Stderr, "stdout:", stderr.String())
		fmt.Fprintln(os.Stderr, "stderr:", stderr.String())
		fmt.Fprintln(os.Stderr, "exit-code:", exit.ExitCode())
	} else {
		result.ExitCode = 1
		result.Output = err.Error()
		fmt.Fprintln(os.Stderr, "stdout:", stderr.String())
		fmt.Fprintln(os.Stderr, "stderr:", stderr.String())
		fmt.Fprintln(os.Stderr, "error:", err.Error())
	}

	return json.NewEncoder(output).Encode(result)
}
