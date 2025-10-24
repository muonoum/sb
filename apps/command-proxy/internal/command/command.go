package command

import (
	"context"
	"encoding/json"
	"io"
	"os/exec"
	"strings"
	"time"

	"github.com/rs/zerolog/log"
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
		log.Error().Int("exit-code", exit.ExitCode()).
			Str("stdout", stdout.String()).Str("stderr", stderr.String()).
			Msg("bad exit code")

		result.ExitCode = exit.ExitCode()
		result.Output = stderr.String()
	} else {
		log.Error().Err(err).
			Str("stdout", stdout.String()).Str("stderr", stderr.String()).
			Msg("command failed")

		result.ExitCode = 1
		result.Output = err.Error()
	}

	return json.NewEncoder(output).Encode(result)
}
