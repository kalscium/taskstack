//! Functions for dealing with memory-block based stacks

const std = @import("std");
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

/// Pushes a sized binary slice to the memory block
pub fn block_push(allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    // open the memory block
    const file = try root.block.open(allocator, path);
    defer file.close();

    // read the memory block metadata
    var mb_buffer: [@sizeOf(u16)*3]u8 = [_]u8{0} ** (@sizeOf(u16)*3);
    _ = try file.readAll(&mb_buffer);
    var metadata = root.block.MetaData.decode(&mb_buffer);

    // check for space on the content stack
    if (@as(u16, @intCast(bytes.len)) > root.block.block_size - metadata.content_stack_ptr) {
        root.printManifesto();
        return error.TStackOverflow;
    }
    // check for space on the size stack
    if (@sizeOf(u16) > metadata.content_stack_base - metadata.size_stack_ptr) {
        root.printManifesto();
        return error.TStackOverflow;
    }

    // push the contents to the content stack
    try push(file, &metadata.content_stack_ptr, bytes);

    // push the size of the content to the size stack
    const encoded_size = std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(bytes.len)));
    try push(file, &metadata.size_stack_ptr, &encoded_size);

    // update the memory block metadata
    metadata.encode(&mb_buffer);
    try file.seekTo(0);
    try file.writeAll(&mb_buffer);
}

/// Pops a binary slice off the memory block and returns it.
/// Returned slice is owned by the caller.
pub fn block_pop(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    // open the memory block
    const file = try root.block.open(allocator, path);
    defer file.close();

    // read the memory block metadata
    var mb_buffer: [@sizeOf(u16)*3]u8 = [_]u8{0} ** (@sizeOf(u16)*3);
    _ = try file.readAll(&mb_buffer);
    var metadata = root.block.MetaData.decode(&mb_buffer);

    // check if the size stack is empty
    if (metadata.size_stack_ptr == @sizeOf(u16) * 3)
        return error.EmptyTStack;
    // check if the content stack is empty
    if (metadata.content_stack_ptr == metadata.content_stack_base)
        return error.EmptyTStack;

    // pop the slice size off the size stack
    var sz_buffer: [@sizeOf(u16)]u8 = undefined;
    try pop(file, &metadata.size_stack_ptr, &sz_buffer);
    const sz = std.mem.bigToNative(u16, std.mem.bytesToValue(u16, &sz_buffer));

    // pop the actual contents off the content stack
    const content = try allocator.alloc(u8, sz);
    try pop(file, &metadata.content_stack_ptr, content);

    // update the memory block metadata
    metadata.encode(&mb_buffer);
    try file.seekTo(0);
    try file.writeAll(&mb_buffer);

    return content;
}
