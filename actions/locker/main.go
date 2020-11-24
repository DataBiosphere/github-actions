package main

import (
	"fmt"
	"github.com/edwarnicke/debug"
	"github.com/marcacohen/gcslock"
	"log"
	"os"
)

func main() {
	if err := debug.Self(); err != nil {
		log.Printf("%s", err)
	}

	bucket := os.Getenv("INPUT_BUCKET")
	lockName := os.Getenv("INPUT_LOCK_NAME")
	operation := os.Getenv("INPUT_OPERATION")

	m, err := gcslock.New(nil, bucket, lockName)
	if err != nil {
		log.Fatal(err)
	}
	if operation == "lock" {
		m.Lock()
		log.Printf("%s locked", lockName)
	} else if operation == "unlock" {
		m.Unlock()
		log.Printf("%s unlocked", lockName)
	} else {
		log.Fatal(fmt.Sprintf("Unsupported operation %s", operation))
	}
}
