//! Functions for dealing with memory-block based stacks

const std = @import("std");
const datetime = @import("datetime");
const root = @import("root.zig");

/// Pushes a binary slice to the stack
pub fn push(file: std.fs.File, stack_ptr: *u16, bytes: []const u8) !void {
    try file.seekTo(stack_ptr.*);
    try file.writeAll(bytes);
    stack_ptr.* += @intCast(bytes.len);
}

/// Pops a binary slice off the stack based on a provided buffer and it's length
pub fn pop(file: std.fs.File, stack_ptr: *u16, buffer: []u8) !void {
    stack_ptr.* -= @intCast(buffer.len);
    try file.seekTo(stack_ptr.*);
    _ = try file.readAll(buffer);
}

/// Returns a the original slice with a timestamp prepended at the start that's owned by the caller
pub fn addTimestamp(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const now = std.time.milliTimestamp();
    const extra_bytes = std.mem.toBytes(std.mem.nativeToBig(i64, now));
    const wrapped = try std.mem.concat(allocator, u8, &.{ &extra_bytes, bytes });
    return wrapped;
}

/// Extracts and returns a string timestamp from a slice that's owned by the caller
pub fn extractTimestamp(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const timestamp = std.mem.bigToNative(i64, std.mem.bytesToValue(i64, bytes));
    return try datetime.datetime.Datetime.fromTimestamp(timestamp).formatISO8601(allocator, true);
}
