const std = @import("std");
const tile = @import("tile.zig");

const SHOP_TILES_PER_SET = 4;
const TILE_INDEX_TYPE = u2;

/// Shop error.
const ShopError = error{
    DoesNotExist,
    OutOfBounds,
};

/// Shop to buy tiles from.
pub fn Shop(comptime num_sets: usize) type {
    return struct {
        const Self = @This();
        /// Tiles in the shop.
        tiles: [num_sets * SHOP_TILES_PER_SET]?tile.Tile = [_]?tile.Tile{null} ** (num_sets * SHOP_TILES_PER_SET),

        /// Get the absolute tile index of a tile in the struct.
        fn absoluteTileIndex(set_index: usize, tile_index: TILE_INDEX_TYPE) usize {
            return set_index * SHOP_TILES_PER_SET + tile_index;
        }

        /// If the valid set and tile index is valid.
        pub fn isValidIndex(set_index: usize, tile_index: TILE_INDEX_TYPE) bool {
            return set_index < num_sets and tile_index < SHOP_TILES_PER_SET;
        }

        /// Get the number of set slots.
        pub fn numSetSlots() usize {
            return num_sets;
        }

        /// Peek at a tile in the shop. The pointer returned is not owned.
        pub fn peek(self: *Self, set_index: usize, tile_index: TILE_INDEX_TYPE) !*?tile.Tile {
            if (!Self.isValidIndex(set_index, tile_index))
                return error.OutOfBounds;
            return &self.tiles[absoluteTileIndex(set_index, tile_index)];
        }

        /// Place a tile item at an index.
        pub fn place(self: *Self, set_index: usize, tile_index: TILE_INDEX_TYPE, item: tile.Tile) !void {
            const loc = try self.peek(set_index, tile_index);
            loc.* = item;
        }

        /// Take a tile from an index and replaces it will null, otherwise returns an error.
        pub fn take(self: *Self, set_index: usize, tile_index: TILE_INDEX_TYPE) !tile.Tile {
            const loc = try self.peek(set_index, tile_index);
            if (loc.*) |tmp| {
                loc.* = null;
                return tmp;
            } else return error.DoesNotExist;
        }
    };
}

test "Shop" {
    var shop: Shop(3) = .{};
    try std.testing.expect(Shop(3).numSetSlots() == 3);
    try std.testing.expect(Shop(3).isValidIndex(2, 0));
    try std.testing.expect(!Shop(3).isValidIndex(4, 0));
    try std.testing.expectError(error.OutOfBounds, shop.peek(3, 0));
    try std.testing.expectError(error.OutOfBounds, shop.place(4, 0, .{
        .number = 0,
        .tile_type = .Invalid,
        .upside_down = false,
    }));
    try std.testing.expectError(error.OutOfBounds, shop.take(5, 0));
    try std.testing.expectError(error.DoesNotExist, shop.take(1, 1));
    const sample = tile.Tile{
        .number = 7,
        .tile_type = .Bamboo,
        .upside_down = true,
    };
    try shop.place(1, 1, sample);
    try std.testing.expect(std.meta.eql(shop.take(1, 1), sample));
    try std.testing.expectError(error.DoesNotExist, shop.take(1, 1));
}
