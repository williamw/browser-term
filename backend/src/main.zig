const std = @import("std");
const protocol = @import("protocol.zig");
const pty_mod = @import("pty.zig");
const session_mod = @import("session.zig");
const ws_handler = @import("ws_handler.zig");

const PORT: u16 = 7681;
const ADDRESS = "127.0.0.1";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("browser-term-server starting on ws://{s}:{d}", .{ ADDRESS, PORT });

    var manager = session_mod.SessionManager.init(allocator);
    defer manager.deinit();

    // Start cleanup thread
    const cleanup_thread = try std.Thread.spawn(.{}, cleanupLoop, .{&manager});
    defer cleanup_thread.detach();

    // Start WebSocket server
    // TODO: integrate karlseguin/websocket.zig server
    // For now, use std.net to listen and accept connections
    // This will be replaced with the proper websocket server in Green Phase 4
    const address = try std.net.Address.parseIp4(ADDRESS, PORT);
    var server = try address.listen(.{});
    defer server.deinit();

    std.log.info("Listening on ws://{s}:{d}", .{ ADDRESS, PORT });

    while (true) {
        const conn = server.accept() catch |err| {
            std.log.err("Accept error: {}", .{err});
            continue;
        };
        _ = conn;
        // TODO: Hand off to websocket handler
    }
}

fn cleanupLoop(manager: *session_mod.SessionManager) void {
    while (true) {
        std.time.sleep(5 * std.time.ns_per_s);
        manager.cleanup(30);
    }
}
