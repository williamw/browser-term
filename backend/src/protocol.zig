const std = @import("std");

// ── Client → Server Messages ──────────────────────────────────────────

pub const NewSessionPayload = struct {};

pub const AttachPayload = struct {
    session_id: []const u8,
};

pub const InputPayload = struct {
    session_id: []const u8,
    data: []const u8,
};

pub const ResizePayload = struct {
    session_id: []const u8,
    cols: u16,
    rows: u16,
};

pub const ClientMessage = union(enum) {
    new_session: NewSessionPayload,
    attach: AttachPayload,
    input: InputPayload,
    resize: ResizePayload,
};

// ── Server → Client Messages ──────────────────────────────────────────

pub const SessionCreatedPayload = struct {
    session_id: []const u8,
};

pub const OutputPayload = struct {
    session_id: []const u8,
    data: []const u8,
};

pub const SessionEndedPayload = struct {
    session_id: []const u8,
};

pub const ErrorPayload = struct {
    message: []const u8,
};

pub const ServerMessage = union(enum) {
    session_created: SessionCreatedPayload,
    output: OutputPayload,
    session_ended: SessionEndedPayload,
    @"error": ErrorPayload,
};

// ── JSON structure for parsing ────────────────────────────────────────

const RawMessage = struct {
    type: []const u8,
    session_id: ?[]const u8 = null,
    data: ?[]const u8 = null,
    cols: ?u16 = null,
    rows: ?u16 = null,
    message: ?[]const u8 = null,
};

// ── Parsing ───────────────────────────────────────────────────────────

pub const ParseError = error{
    UnknownMessageType,
    MissingField,
};

pub fn parseClientMessage(json: []const u8) !ClientMessage {
    const parsed = std.json.parseFromSlice(RawMessage, std.heap.page_allocator, json, .{
        .ignore_unknown_fields = true,
    }) catch {
        return error.UnknownMessageType;
    };
    const raw = parsed.value;

    if (std.mem.eql(u8, raw.type, "new_session")) {
        return .{ .new_session = .{} };
    } else if (std.mem.eql(u8, raw.type, "attach")) {
        return .{ .attach = .{
            .session_id = raw.session_id orelse return error.MissingField,
        } };
    } else if (std.mem.eql(u8, raw.type, "input")) {
        return .{ .input = .{
            .session_id = raw.session_id orelse return error.MissingField,
            .data = raw.data orelse return error.MissingField,
        } };
    } else if (std.mem.eql(u8, raw.type, "resize")) {
        return .{ .resize = .{
            .session_id = raw.session_id orelse return error.MissingField,
            .cols = raw.cols orelse return error.MissingField,
            .rows = raw.rows orelse return error.MissingField,
        } };
    }

    return error.UnknownMessageType;
}

// ── Serialization ─────────────────────────────────────────────────────

pub fn serializeServerMessage(allocator: std.mem.Allocator, msg: ServerMessage) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();
    const writer = buf.writer();

    try writer.writeAll("{");

    switch (msg) {
        .session_created => |payload| {
            try writer.writeAll("\"type\":\"session_created\",\"session_id\":");
            try std.json.stringify(payload.session_id, .{}, writer);
        },
        .output => |payload| {
            try writer.writeAll("\"type\":\"output\",\"session_id\":");
            try std.json.stringify(payload.session_id, .{}, writer);
            try writer.writeAll(",\"data\":");
            try std.json.stringify(payload.data, .{}, writer);
        },
        .session_ended => |payload| {
            try writer.writeAll("\"type\":\"session_ended\",\"session_id\":");
            try std.json.stringify(payload.session_id, .{}, writer);
        },
        .@"error" => |payload| {
            try writer.writeAll("\"type\":\"error\",\"message\":");
            try std.json.stringify(payload.message, .{}, writer);
        },
    }

    try writer.writeAll("}");

    return buf.toOwnedSlice();
}

// ── Tests ──────────────────────────────────────────────────────────────

test "parse new_session message" {
    const msg = try parseClientMessage("{\"type\":\"new_session\"}");
    try std.testing.expect(msg == .new_session);
}

test "parse attach message" {
    const msg = try parseClientMessage("{\"type\":\"attach\",\"session_id\":\"abc123\"}");
    try std.testing.expect(msg == .attach);
    try std.testing.expectEqualStrings("abc123", msg.attach.session_id);
}

test "parse input message" {
    const msg = try parseClientMessage("{\"type\":\"input\",\"session_id\":\"abc123\",\"data\":\"ls\\r\"}");
    try std.testing.expect(msg == .input);
    try std.testing.expectEqualStrings("abc123", msg.input.session_id);
    try std.testing.expectEqualStrings("ls\r", msg.input.data);
}

test "parse resize message" {
    const msg = try parseClientMessage("{\"type\":\"resize\",\"session_id\":\"abc123\",\"cols\":120,\"rows\":40}");
    try std.testing.expect(msg == .resize);
    try std.testing.expectEqualStrings("abc123", msg.resize.session_id);
    try std.testing.expectEqual(@as(u16, 120), msg.resize.cols);
    try std.testing.expectEqual(@as(u16, 40), msg.resize.rows);
}

test "parse invalid message type returns error" {
    const result = parseClientMessage("{\"type\":\"unknown\"}");
    try std.testing.expectError(error.UnknownMessageType, result);
}

test "parse malformed json returns error" {
    const result = parseClientMessage("not json at all");
    try std.testing.expect(if (result) |_| false else |_| true);
}

test "serialize session_created message" {
    const allocator = std.testing.allocator;
    const json = try serializeServerMessage(allocator, .{
        .session_created = .{ .session_id = "abc123" },
    });
    defer allocator.free(json);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("session_created", obj.get("type").?.string);
    try std.testing.expectEqualStrings("abc123", obj.get("session_id").?.string);
}

test "serialize output message" {
    const allocator = std.testing.allocator;
    const json = try serializeServerMessage(allocator, .{
        .output = .{ .session_id = "abc123", .data = "hello\n" },
    });
    defer allocator.free(json);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("output", obj.get("type").?.string);
    try std.testing.expectEqualStrings("abc123", obj.get("session_id").?.string);
    try std.testing.expectEqualStrings("hello\n", obj.get("data").?.string);
}

test "serialize session_ended message" {
    const allocator = std.testing.allocator;
    const json = try serializeServerMessage(allocator, .{
        .session_ended = .{ .session_id = "abc123" },
    });
    defer allocator.free(json);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("session_ended", obj.get("type").?.string);
    try std.testing.expectEqualStrings("abc123", obj.get("session_id").?.string);
}

test "serialize error message" {
    const allocator = std.testing.allocator;
    const json = try serializeServerMessage(allocator, .{
        .@"error" = .{ .message = "not found" },
    });
    defer allocator.free(json);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("error", obj.get("type").?.string);
    try std.testing.expectEqualStrings("not found", obj.get("message").?.string);
}
