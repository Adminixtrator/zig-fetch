const std = @import("std");
const http = std.http;
const heap = std.heap;

const Client = http.Client;
const RequestOptions = Client.RequestOptions;

const Token = struct {
    address: []const u8,
    address_label: ?[]const u8,
    name: []const u8,
    symbol: []const u8,
    decimals: []const u8,
    logo: []const u8,
    logo_hash: ?[]const u8,
    thumbnail: []const u8,
    total_supply: []const u8,
    total_supply_formatted: []const u8,
    block_number: []const u8,
    validated: u8,
    created_at: []const u8,
    possible_spam: bool,
    verified_contract: bool,
    security_score: ?u8,
};

const PairData = struct {
    token0: Token,
    token1: Token,
    pairAddress: []const u8,
};

const Todo = struct {
    userId: usize,
    id: usize,
    title: []const u8,
    completed: bool,
};

const Post = struct {
    userId: usize,
    body: []const u8,
    title: []const u8,
};

const FetchReq = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;

    allocator: Allocator,
    client: std.http.Client,
    body: std.ArrayList(u8),

    pub fn init(allocator: Allocator) Self {
        const c = Client{ .allocator = allocator };
        return Self{
            .allocator = allocator,
            .client = c,
            .body = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
        self.body.deinit();
    }

    /// Blocking
    pub fn get(self: *Self, url: []const u8, headers: []http.Header) !Client.FetchResult {
        const fetch_options = Client.FetchOptions{
            .location = Client.FetchOptions.Location{
                .url = url,
            },
            .extra_headers = headers,
            .response_storage = .{ .dynamic = &self.body },
        };

        const res = try self.client.fetch(fetch_options);
        return res;
    }

    /// Blocking
    pub fn post(self: *Self, url: []const u8, body: []const u8, headers: []http.Header) !Client.FetchResult {
        const fetch_options = Client.FetchOptions{
            .location = Client.FetchOptions.Location{
                .url = url,
            },
            .extra_headers = headers,
            .method = .POST,
            .payload = body,
            .response_storage = .{ .dynamic = &self.body },
        };

        const res = try self.client.fetch(fetch_options);
        return res;
    }
};

pub fn main() !void {
    var gpa_impl = heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa_impl.deinit() == .leak) {
        std.log.warn("Has leaked\n", .{});
    };
    const gpa = gpa_impl.allocator();

    var req = FetchReq.init(gpa);
    defer req.deinit();

    // GET request
    {
        const get_url = "YOUR_URL";

        var headers = [_]http.Header{
            http.Header{
                .name = "KEY",
                .value = "VALUE"
            }
        };
        const res = try req.get(get_url, &headers);
        const body = try req.body.toOwnedSlice();
        defer req.allocator.free(body);

        if (res.status != .ok) {
            std.log.err("GET request failed - {s}\n", .{body});            
        }

        const parsed = try std.json.parseFromSlice(PairData, gpa, body, .{});
        defer parsed.deinit();

        // const todo = Todo{
        //     .userId = parsed.value.userId,
        //     .id = parsed.value.id,
        //     .title = parsed.value.title,
        //     .completed = parsed.value.completed,
        // };

        // std.debug.print(
        //     \\ GET response body struct -
        //     \\ user ID - {d}
        //     \\ id {d}
        //     \\ title {s}
        //     \\ completed {}
        //     \\
        // , .{ todo.userId, todo.id, todo.title, todo.completed });

        std.debug.print("Parsed Data: {s}", .{parsed.value.pairAddress});
    }

    // POST request
    {
        const post_url = "https://jsonplaceholder.typicode.com/posts";
        const new_post = Post{
            .title = "Simple fetch requests with Zig",
            .body = "Make sure to like and subscribe ;)",
            .userId = 1,
        };

        const json_post = try std.json.stringifyAlloc(gpa, new_post, .{});
        defer gpa.free(json_post);

        var headers = [_]http.Header{.{ .name = "content-type", .value = "application/json" }};
        const res = try req.post(post_url, json_post, &headers);
        const body = try req.body.toOwnedSlice();
        defer req.allocator.free(body);

        if (res.status != .created) {
            std.log.err("POST request failed - {?s}\n", .{body});
        }

        std.debug.print("POST response body - {s}\n", .{body});
    }
}
