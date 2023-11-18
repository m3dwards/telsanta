FROM cgr.dev/chainguard/zig:latest-dev as builder
COPY --chown=nonroot . /app
WORKDIR /app
RUN zig build

FROM cgr.dev/chainguard/static
COPY --from=builder /app/zig-out/bin/telsanta /usr/local/bin/telsanta
CMD ["/usr/local/bin/telsanta"]