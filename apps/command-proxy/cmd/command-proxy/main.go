package main

import (
	"context"
	"io"
	"net"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"sb/command-proxy/internal/command"
)

func init() {
	log.Logger = zerolog.New(zerolog.ConsoleWriter{
		Out: os.Stderr, FormatTimestamp: func(_ any) string { return "" },
	})
}

func main() {
	address := os.Getenv("PROXY_ADDRESS")

	if address != "" {
		if err := listen(address); err != nil {
			log.Fatal().Err(err).Msg("could not start listener")
		}
	} else if err := handler(os.Stdin, os.Stdout); err != nil {
		log.Fatal().Err(err).Msg("could not start handler")
	}
}

func handler(input io.Reader, output io.Writer) error {
	spec, err := command.New(input)
	if err != nil {
		return err
	}

	log.Info().
		Str("executable", spec.Executable).
		Strs("arguments", spec.Arguments).
		Float64("timeout", spec.Timeout).
		Interface("stdin", spec.Stdin).
		Msg("run command")

	return spec.Run(context.Background(), output)
}

func listen(address string) error {
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return err
	}

	defer listener.Close()
	log.Info().Str("address", address).Msg("started listener")

	for {
		conn, err := listener.Accept()
		if err != nil {
			return err
		}

		go accept(conn)
	}

}

func accept(conn net.Conn) {
	defer conn.Close()

	if err := handler(conn, conn); err != nil {
		log.Fatal().Err(err).Msg("could not start handler")
	}
}
