//! Functions for dealing with file memory-blocks

const std = @import("std");
const root = @import("root.zig");

/// The size of memory blocks (shouldn't be to big to allow for stack overflows)
pub const block_size = 512;

/// Block meta-data
pub const MetaData = struct {
    /// The size stack pointer
    size_stack_ptr: u16,
    /// The content stack pointer
    content_stack_ptr: u16,
    /// The pointer to the base of the content stack
    content_stack_base: u16,

    /// Writes the encoded metadata to a buffer
    pub fn encode(self: MetaData, buffer: *[@sizeOf(u16)*3]u8) void {
        const size_stack_ptr = std.mem.nativeToBig(u16, self.size_stack_ptr);
        const content_stack_ptr = std.mem.nativeToBig(u16, self.content_stack_ptr);
        const content_stack_base = std.mem.nativeToBig(u16, self.content_stack_base);

        std.mem.copyForwards(u8, buffer[0..], &std.mem.toBytes(size_stack_ptr));
        std.mem.copyForwards(u8, buffer[@sizeOf(u16)..], &std.mem.toBytes(content_stack_ptr));
        std.mem.copyForwards(u8, buffer[@sizeOf(u16)*2..], &std.mem.toBytes(content_stack_base));
    }

    /// Decodes the encoded metadata from a buffer
    pub fn decode(buffer: *const [@sizeOf(u16)*3]u8) MetaData {
        const size_stack_ptr = std.mem.bytesToValue(u16, buffer[0..@sizeOf(u16)]);
        const content_stack_ptr = std.mem.bytesToValue(u16, buffer[@sizeOf(u16)..@sizeOf(u16)*2]);
        const content_stack_base = std.mem.bytesToValue(u16, buffer[@sizeOf(u16)*2..@sizeOf(u16)*3]);

        return MetaData{
            .size_stack_ptr = std.mem.bigToNative(u16, size_stack_ptr),
            .content_stack_ptr = std.mem.bigToNative(u16, content_stack_ptr),
            .content_stack_base = std.mem.bigToNative(u16, content_stack_base),
        };
    }
};

/// Initialises a memory block
pub fn init(allocator: std.mem.Allocator, path: []const u8) !void {
    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    // initialise the block
    const block = try allocator.alloc(u8, block_size);
    defer allocator.free(block);

    // encode the metadata
    const initial: MetaData = .{
        .size_stack_ptr = 3 * @sizeOf(u16),
        .content_stack_ptr = 3 * @sizeOf(u16) + block_size / 4,
        .content_stack_base = 3 * @sizeOf(u16) + block_size / 4,
    };

    // write the meta-data
    initial.encode(@ptrCast(block.ptr));

    try file.writeAll(block);
}

/// Opens a memory block and returns a file that's owned by the caller
pub fn open(allocator: std.mem.Allocator, path: []const u8) !std.fs.File {
    // check if it exists
    if (std.fs.accessAbsolute(path, .{})) {}
    else |err| switch (err) {
        error.FileNotFound => try init(allocator, path),
        else => return err,
    }

    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_write, .lock = .exclusive });
    return file;
}

/// Returns the path to the short-term memory block that's owned by the caller
pub fn shortTermPath(allocator: std.mem.Allocator) ![]const u8 {
    const home = try root.getHome(allocator);
    defer allocator.free(home);
    const path = try std.fmt.allocPrint(allocator, "{s}/short-term.tsk", .{home});
    return path;
}

/// Returns the path to the long-term memory block that's owned by the caller
pub fn longTermPath(allocator: std.mem.Allocator) ![]const u8 {
    const home = try root.getHome(allocator);
    defer allocator.free(home);
    const path = try std.fmt.allocPrint(allocator, "{s}/long-term.tsk", .{home});
    return path;
}

/// Pushes a sized binary slice to the memory block
pub fn push(allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
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
    try root.stack.push(file, &metadata.content_stack_ptr, bytes);

    // push the size of the content to the size stack
    const encoded_size = std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(bytes.len)));
    try root.stack.push(file, &metadata.size_stack_ptr, &encoded_size);

    // update the memory block metadata
    metadata.encode(&mb_buffer);
    try file.seekTo(0);
    try file.writeAll(&mb_buffer);
}

/// Pops a binary slice off the memory block and returns it.
/// Returned slice is owned by the caller.
pub fn pop(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
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
    try root.stack.pop(file, &metadata.size_stack_ptr, &sz_buffer);
    const sz = std.mem.bigToNative(u16, std.mem.bytesToValue(u16, &sz_buffer));

    // pop the actual contents off the content stack
    const content = try allocator.alloc(u8, sz);
    try root.stack.pop(file, &metadata.content_stack_ptr, content);

    // update the memory block metadata
    metadata.encode(&mb_buffer);
    try file.seekTo(0);
    try file.writeAll(&mb_buffer);

    return content;
}

/// Prints all the byte slices in a memory block to stdout
pub fn list(allocator: std.mem.Allocator, path: []const u8) !void {
    // open the memory block
    var file = try open(allocator, path);
    defer file.close();

    // read the memory block metadata
    var mb_buffer: [@sizeOf(u16)*3]u8 = [_]u8{0} ** (@sizeOf(u16)*3);
    _ = try file.readAll(&mb_buffer);
    const metadata = root.block.MetaData.decode(&mb_buffer);
    const size_stack_base = @sizeOf(u16)*3;
    
    // calculate the length (how many entries are in the stack)
    // 
    // calculated based upon the size stack as the lengths are known (u16)
    const length = (metadata.size_stack_ptr - size_stack_base) / @sizeOf(u16);

    // both create an array of all the lengths and also find the longest content length
    var longest_len: usize = 0;
    var sizes = try allocator.alloc(u16, length);
    defer allocator.free(sizes);
    for (0..length) |i| {
        // get the size of the contents
        var sz_buffer: [@sizeOf(u16)]u8 = undefined;
        try file.seekTo(size_stack_base + i * @sizeOf(u16));
        _ = try file.readAll(&sz_buffer);
        const sz = std.mem.bigToNative(u16, std.mem.bytesToValue(u16, &sz_buffer));

        // update the longest length & sizes array
        sizes[i] = sz;
        if (sz > longest_len)
            longest_len = sz;
    }

    // iterate through all the content stack entries and print them
    var content_ptr = metadata.content_stack_base;
    var stdout = std.io.getStdOut();
    for (sizes) |sz| {
        // get the contents
        const contents = try allocator.alloc(u8, sz);
        defer allocator.free(contents);
        try file.seekTo(content_ptr);
        _ = try file.readAll(contents);

        // calculate the padding
        const padding_sz = longest_len - sz;
        const padding = try allocator.alloc(u8, padding_sz);
        defer allocator.free(padding);
        for (0..padding_sz) |i| {
            padding[i] = ' ';
        }

        // get the iso timestamp
        const timestamp = try root.stack.extractTimestamp(allocator, contents);
        defer allocator.free(timestamp);

        // print it
        std.debug.print("* ", .{});
        _ = try stdout.writeAll(contents[@sizeOf(i64)..]);
        std.debug.print("{s} | {s}\n", .{ padding, timestamp });
        
        // update the content ptr
        content_ptr += sz;
    }
}
