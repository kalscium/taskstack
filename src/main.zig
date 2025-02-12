const std = @import("std");
const taskstack = @import("taskstack");

pub fn main() !void {
    // initialise the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // get the args
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    // check for no args
    if (args.len == 1) {
        printHelp();
        return;
    }

    // check for the help option
    if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        printHelp();
        return;
    }

    // check for the version option
    if (std.mem.eql(u8, args[1], "--version") or std.mem.eql(u8, args[1], "-V")) {
        std.debug.print("taskstack {s}\n", .{taskstack.version});
        return;
    }

    // check for the 'wipe' commands
    if (std.mem.eql(u8, args[1], "swipe")) {
        const path = try taskstack.block.shortTermPath(allocator);
        defer allocator.free(path);
        try taskstack.block.init(allocator, path);
        return;
    }
    if (std.mem.eql(u8, args[1], "lwipe")) {
        const path = try taskstack.block.longTermPath(allocator);
        defer allocator.free(path);
        try taskstack.block.init(allocator, path);
        return;
    }

    // check for the 'list' commands
    if (std.mem.eql(u8, args[1], "slist")) {
        const path = try taskstack.block.shortTermPath(allocator);
        defer allocator.free(path);
        std.debug.print("<<< SHORT-TERM STACK ENTRIES >>>\n", .{});
        try taskstack.block.list(allocator, path);
        return;
    }
    if (std.mem.eql(u8, args[1], "llist")) {
        const path = try taskstack.block.longTermPath(allocator);
        defer allocator.free(path);
        std.debug.print("<<< LONG-TERM STACK ENTRIES >>>\n", .{});
        try taskstack.block.list(allocator, path);
        return;
    }

    // check for the 'push' commands
    if (std.mem.eql(u8, args[1], "spush")) {
        // get the stack entry contents
        if (args.len < 3)
            return error.ExpectedArgument;
        const contents = try taskstack.stack.addTimestamp(allocator, args[2]);
        defer allocator.free(contents);

        const path = try taskstack.block.shortTermPath(allocator);
        defer allocator.free(path);

        try taskstack.block.push(allocator, path, contents);
        return;
    }
    if (std.mem.eql(u8, args[1], "lpush")) {
        // get the stack entry contents
        if (args.len < 3)
            return error.ExpectedArgument;
        const contents = try taskstack.stack.addTimestamp(allocator, args[2]);
        defer allocator.free(contents);

        const path = try taskstack.block.longTermPath(allocator);
        defer allocator.free(path);

        try taskstack.block.push(allocator, path, contents);
        return;
    }

    // check for the 'pop' commands
    if (std.mem.eql(u8, args[1], "spop")) {
        const path = try taskstack.block.shortTermPath(allocator);
        defer allocator.free(path);
        const contents = try taskstack.block.pop(allocator, path);
        defer allocator.free(contents);
        const timestamp = try taskstack.stack.extractTimestamp(allocator, contents);
        defer allocator.free(timestamp);
        std.debug.print("popped value ({s}): ", .{timestamp});
        try std.io.getStdOut().writeAll(contents[@sizeOf(i64)..]);
        std.debug.print("\n", .{});
        return;
    }
    if (std.mem.eql(u8, args[1], "lpop")) {
        const path = try taskstack.block.longTermPath(allocator);
        defer allocator.free(path);
        const contents = try taskstack.block.pop(allocator, path);
        defer allocator.free(contents);
        const timestamp = try taskstack.stack.extractTimestamp(allocator, contents);
        defer allocator.free(timestamp);
        std.debug.print("popped value ({s}): ", .{timestamp});
        try std.io.getStdOut().writeAll(contents[@sizeOf(i64)..]);
        std.debug.print("\n", .{});
        return;
    }

    // if nothing matches it
    return error.UnknownCommandOrOption;
}

/// Prints the help menu message
fn printHelp() void {
    const help =
        \\Usage: taskstack [command] [argument]
        \\Short-Term Stack Commands:
        \\    swipe         | wipes all short-term tasks
        \\    slist         | lists all the tasks and their creation dates on the short-term stack
        \\    spush <task>  | pushes a task to the short-term stack
        \\    spop          | pops the latest task from the short-term stack
        \\Long-Term Stack Commands:
        \\    lwipe         | wipes all long-term tasks
        \\    llist         | lists all the tasks and their creation dates on the long-term stack
        \\    lpush <task>  | pushes a task to the long-term stack
        \\    lpop          | pops the latest task from the long-term stack
        \\Options:
        \\    -h, --help    | prints this help message
        \\    -V, --version | prints the version
        \\
    ;
    std.debug.print(help, .{});
}
