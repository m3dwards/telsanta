const std = @import("std");

pub fn main() !void { // our http client, this can make multiple requests (and is even threadsafe, although individual requests are not).
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var client = std.http.Client{
        .allocator = allocator,
    };

    // we can `catch unreachable` here because we can guarantee that this is a valid url.
    const uri = std.Uri.parse("https://example.com") catch unreachable;

    // these are the headers we'll be sending to the server
    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    try headers.append("accept", "*/*"); // tell the server we'll accept anything

    // make the connection and set up the request
    var req = try client.request(.GET, uri, headers, .{});
    defer req.deinit();

    // I'm making a GET request, so do I don't need this, but I'm sure someone will.
    // req.transfer_encoding = .chunked;

    // send the request and headers to the server.
    try req.start();

    // try req.writer().writeAll("Hello, World!\n");
    // try req.finish();

    // wait for the server to send use a response
    try req.wait();

    // read the content-type header from the server, or default to text/plain
    const content_type = req.response.headers.getFirstValue("content-type") orelse "text/plain";
    _ = content_type;

    // read the entire response body, but only allow it to allocate 8kb of memory
    const body = req.reader().readAllAlloc(allocator, 8192) catch unreachable;
    defer allocator.free(body);

    std.log.info("{s}", .{body});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
