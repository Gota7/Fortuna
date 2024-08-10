const std = @import("std");
const tile = @import("tile.zig");

/// Tile discard pile.
const Discard = struct {
    const Self = @This();
    /// Collection of tiles.
    tiles: std.ArrayList(tile.Tile),

    // Discard error.
    const DiscardError = error{
        OutOfBounds,
    };

    /// De-initialize the discard pile.
    pub fn deinit(self: Self) void {
        self.tiles.deinit();
    }

    /// Discard a tile.
    pub fn discard(self: *Self, item: tile.Tile) !void {
        return self.tiles.append(item);
    }

    /// Create a new discard pile.
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .tiles = std.ArrayList(tile.Tile).init(allocator),
        };
    }

    /// Swap a tile with one at an index.
    pub fn swap(self: *Self, index: usize, item: tile.Tile) !tile.Tile {
        if (index >= self.tiles.items.len) {
            return error.OutOfBounds;
        }
        const ret = self.tiles.items[index];
        self.tiles.items[index] = item;
        return ret;
    }
};

test "Discard" {
    var discard = Discard.init(std.testing.allocator);
    defer discard.deinit();

    const sample1 = tile.Tile{
        .number = 7,
        .tile_type = .Bamboo,
        .upside_down = true,
    };
    const sample2 = tile.Tile{
        .number = 7,
        .tile_type = .Dot,
        .upside_down = true,
    };
    try discard.discard(sample1);
    try std.testing.expectError(error.OutOfBounds, discard.swap(1, sample2));
    const returned = try discard.swap(0, sample2);
    try std.testing.expect(std.meta.eql(sample1, returned));

    var discard_failing = Discard.init(std.testing.failing_allocator);
    defer discard_failing.deinit();
    try std.testing.expectError(error.OutOfMemory, discard_failing.discard(sample1));
}
