package main

import (
	"context"
	"fmt"
	"github.com/edwarnicke/debug"
	"github.com/marcacohen/gcslock"
	"log"
	"os"
	"strconv"
	"time"
)

func main() {
	// For remote debugging with Delve
	if err := debug.Self(); err != nil {
		log.Printf("%s", err)
	}

	log.Print("Reading environment variables")
	bucket := getEnv("INPUT_BUCKET", "")
	lockName := getEnv("INPUT_LOCK_NAME", "")
	operation := getEnv("INPUT_OPERATION", "")
	continueOnLockTimeout, err := strconv.ParseBool(getEnv("INPUT_CONTINUE_ON_LOCK_TIMEOUT", "false"))
	if err != nil {log.Fatal(err)}
	lockTimeout, err := strconv.Atoi(getEnv("INPUT_LOCK_TIMEOUT_MS", "0"))
	if err != nil {log.Fatal(err)}
	unlockTimeout, err := strconv.Atoi(getEnv("INPUT_UNLOCK_TIMEOUT_MS", "2000"))
	if err != nil {log.Fatal(err)}

	var ctx context.Context
	if operation == "lock" {
		if lockTimeout != 0 {
			log.Printf("Setting lock timeout to %d", lockTimeout)
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(context.Background(), time.Duration(lockTimeout)*time.Millisecond)
			defer cancel()
 		} else {
			log.Print("No lock timeout set")
 			ctx = context.Background()
		}
		m, err := gcslock.New(ctx, bucket, lockName)
		if err != nil {log.Fatal(err)}

		if err = m.ContextLock(ctx); err != nil {
			// Catch DeadlineExceeded error and don't fail if continueOnLockTimeout is true
			if !(err == context.DeadlineExceeded && continueOnLockTimeout) {
				log.Fatal(err)
			} else {
				log.Print("Deadline exceeded, continuing anyway")
			}
		} else {
			log.Printf("The '%s' lock has been locked", lockName)
		}
	} else if operation == "unlock" {
		if unlockTimeout != 0 {
			log.Printf("Setting unlock timeout to %d", lockTimeout)
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(context.Background(), time.Duration(unlockTimeout)*time.Millisecond)
			defer cancel()
		} else {
			log.Print("No unlock timeout set")
			ctx = context.Background()
		}
		m, err := gcslock.New(ctx, bucket, lockName)
		if err != nil {log.Fatal(err)}

		err = m.ContextUnlock(ctx)
		if err != nil {log.Fatal(err)}

		log.Printf("The '%s' lock has been unlocked", lockName)
	} else {
		log.Fatal(fmt.Sprintf("Unsupported operation %s", operation))
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	if fallback == "" {
		log.Fatalf("Required %s environment variable not set!", key)
	}
	return fallback
}
