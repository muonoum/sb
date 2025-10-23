package main

import (
	"context"
	"fmt"
	"io"
	"net"
	"os"

	"sb/command-proxy/internal/command"
)

func main() {
	address := os.Getenv("PROXY_ADDRESS")

	if address != "" {
		if err := listen(address); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	} else if err := handler(os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
}

func handler(input io.Reader, output io.Writer) error {
	spec, err := command.New(input)
	if err != nil {
		return err
	}

	fmt.Fprintln(os.Stderr, "run command", spec)
	return spec.Run(context.Background(), output)
}

func listen(address string) error {
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return err
	}
	defer listener.Close()

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
		fmt.Fprintln(os.Stderr, err)
		return
	}
}
