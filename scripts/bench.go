package main

import (
	"fmt"
	"net"
	"time"
)

func main() {
	// Target the Concrete Core ingestion port (Default: 8080)
	addr, _ := net.ResolveUDPAddr("udp", "127.0.0.1:8080")
	conn, _ := net.DialUDP("udp", nil, addr)
	defer conn.Close()

	// High-pressure burst: 10k iterations to measure sustained throughput
	iterations := 10000

	// Protocol Frame Construction (80 bytes total):
	// [0-7]   Magic Header: "CONCRETE"
	// [8-15]  Block ID: 1 (64-bit Little Endian)
	// [16-79] Data Payload: 64 bytes of raw data
	payload := append([]byte("CONCRETE\x01\x00\x00\x00\x00\x00\x00\x00"), make([]byte, 64)...)
	copy(payload[16:], []byte("BENCHMARK_DATA_STRESS_TEST"))

	fmt.Printf("⚡ Starting Stress Test: %d packets...\n", iterations)
	start := time.Now()

	// Fire-and-forget loop: No artificial delays to maximize kernel UDP buffer pressure
	for i := 0; i < iterations; i++ {
		conn.Write(payload)
	}

	duration := time.Since(start)

	// Metrics Calculation
	fmt.Printf("🏁 Finished in %v\n", duration)
	fmt.Printf("🚀 Throughput: %.2f packets/sec\n", float64(iterations)/duration.Seconds())
}