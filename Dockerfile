# --- Stage 1: Builder ---
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache nasm make binutils

# Copy source code
WORKDIR /build
COPY . .

# Compile all targets (core and trigger)
RUN make clean && make

# --- Stage 2: Runtime ---
FROM alpine:latest

# Install util-linux for 'hexdump' and 'strings'
RUN apk add --no-cache util-linux

WORKDIR /app

# Copy ALL generated binaries (core and trigger)
COPY --from=builder /build/bin ./bin

# Copy the scripts directory for internal container testing
COPY --from=builder /build/scripts ./scripts

# Ensure all scripts are executable
RUN chmod +x ./scripts/*.sh

# Expose ports for Concrete Ingestion and IPC
EXPOSE 8080/udp
EXPOSE 8081/udp

# Start the core by default
# Note: docker-compose will override this for the 'tester' service
CMD ["./bin/concrete_core"]