pub const block = @import("block.zig");
pub const stack = @import("stack.zig");

const std = @import("std");

pub const version = "0.1.0";

/// Returns the home-path of taskstack that's owned by the caller
pub fn getHome(allocator: std.mem.Allocator) ![]const u8 {
    // get env map
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    // get the user-home
    const user_home = env_map.get("HOME") orelse return error.HomeEnvVarUnset;

    // construct and allocate the napkin home
    const home = try std.mem.concat(allocator, u8, &.{ user_home, "/.taskstack" });

    // if the directory doesn't exist, then create it
    if (std.fs.accessAbsolute(home, .{})) {}
    else |err| switch (err) {
        error.FileNotFound => try std.fs.makeDirAbsolute(home),
        else => return err,
    }

    // return the home directory
    return home;
}
