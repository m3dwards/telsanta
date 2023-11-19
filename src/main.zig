const std = @import("std");
const pg = @import("pg");

pub fn main() !void { // our http client, this can make multiple requests (and is even threadsafe, although individual requests are not).
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // start of database stuff

    var pgPassword = try std.process.getEnvVarOwned(allocator, "PGPASSWORD");

    var pool = try pg.Pool.init(allocator, .{ .size = 5, .connect = .{
        .port = 5432,
        .host = "flora.db.elephantsql.com",
    }, .auth = .{
        .username = "pdukhuys",
        .database = "pdukhuys",
        .password = pgPassword,
        .timeout = 10_000,
    } });
    defer pool.deinit();

    var conn = try pool.acquire();
    defer conn.release();

    const sql = "select id, name from users where power > $1";
    var result = conn.query(sql, .{9000}) catch |err| switch (err) {
        error.PG => {
            std.debug.print("PG: {s}", .{conn.err.?.message});
            return err;
        },
        else => return err,
    };
    defer result.deinit();

    while (try result.next()) |row| {
        const id = row.get(i32, 0);
        _ = id;
        // this is only valid until the next call to next(), deinit() or drain()
        const name = row.get([]u8, 1);
        _ = name;
    }

    // end of database stuff

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
