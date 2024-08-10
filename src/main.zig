const std = @import("std");
const shop = @import("mahjong/shop.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("Hello World!\n");
}
