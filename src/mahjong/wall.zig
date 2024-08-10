const std = @import("std");
const tile = @import("tile.zig");

const STANDARD_TILES_PER_SET = 4;
const STANDARD_NUM_MIN = 1;
const STANDARD_NUM_MAX = 9;

const FLOWER_TILES_PER_SET = 1;
const FLOWER_MAX = 4;

const TOXIC_TILES_PER_SET_MIN = 2;
const TOXIC_TILES_PER_SET_MAX = 4;

/// A wall of tiles.
const Wall = struct {
    const Self = @This();
    /// Tiles in the wall.
    tiles: std.ArrayList(tile.Tile),

    /// Add a range of tiles with a given type. Adds tiles_per_num amount of each tile.
    fn addTiles(self: *Self, random: std.rand.Random, tile_type: tile.TileType, start_num: u4, end_num: u4, tiles_per_num: usize, allow_upside_down: bool) !void {
        for (start_num..end_num) |number| {
            for (0..tiles_per_num) |_| {
                var item = tile.Tile{
                    .tile_type = tile_type,
                    .number = @intCast(number),
                    .upside_down = false,
                };
                if (allow_upside_down)
                    item.randomlySpin(random);
                try self.tiles.append(item);
            }
        }
    }

    /// Add a set to the wall.
    fn addSet(self: *Self, random: std.rand.Random, allow_upside_down: bool, add_flowers: bool, add_toxic: bool) !void {
        try self.addTiles(random, tile.TileType.Number, STANDARD_NUM_MIN, STANDARD_NUM_MAX, STANDARD_TILES_PER_SET, allow_upside_down);
        try self.addTiles(random, tile.TileType.Bamboo, STANDARD_NUM_MIN, STANDARD_NUM_MAX, STANDARD_TILES_PER_SET, allow_upside_down);
        try self.addTiles(random, tile.TileType.Dot, STANDARD_NUM_MIN, STANDARD_NUM_MAX, STANDARD_TILES_PER_SET, allow_upside_down);
        try self.addTiles(random, tile.TileType.Wind, 0, @typeInfo(tile.WindType).Enum.fields.len, STANDARD_TILES_PER_SET, allow_upside_down);
        try self.addTiles(random, tile.TileType.Dragon, 0, @typeInfo(tile.DragonType).Enum.fields.len, STANDARD_TILES_PER_SET, allow_upside_down);
        if (add_flowers) {
            try self.addTiles(random, tile.TileType.Flower1, STANDARD_NUM_MIN, FLOWER_MAX, FLOWER_TILES_PER_SET, allow_upside_down);
            try self.addTiles(random, tile.TileType.Flower2, STANDARD_NUM_MIN, FLOWER_MAX, FLOWER_TILES_PER_SET, allow_upside_down);
        }
        if (add_toxic)
            try self.addTiles(random, tile.TileType.Toxic, 0, 0, random.intRangeAtMost(usize, TOXIC_TILES_PER_SET_MIN, TOXIC_TILES_PER_SET_MAX), false);
    }

    /// Initialize the wall with tiles.
    pub fn init(allocator: std.mem.Allocator, random: std.rand.Random, num_sets: usize, allow_upside_down: bool, add_flowers: bool, add_toxic: bool) !Self {
        var ret = Self{
            .tiles = std.ArrayList(tile.Tile).init(allocator),
        };
        for (0..num_sets) |_|
            try ret.addSet(random, allow_upside_down, add_flowers, add_toxic);
        random.shuffle(tile.Tile, ret.tiles.items);
        return ret;
    }

    /// De-initialize the wall of tiles.
    pub fn deinit(self: Self) void {
        self.tiles.deinit();
    }

    /// Draw a tile or return null.
    pub fn draw(self: *Self) ?tile.Tile {
        return self.tiles.popOrNull();
    }
};

test "Wall" {
    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();
    var wall = try Wall.init(std.testing.allocator, random, 2, true, true, true);
    defer wall.deinit();
    try std.testing.expect(wall.draw() != null);
    try std.testing.expectError(error.OutOfMemory, Wall.init(std.testing.failing_allocator, random, 2, true, true, true));
}
