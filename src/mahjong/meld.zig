const std = @import("std");
const tile = @import("tile.zig");

const MELD_SIZE = 3;

pub const Meld = struct {
    const Self = @This();
    /// Tiles in the meld, up to 3.
    tiles: [MELD_SIZE]tile.Tile,
    /// If only the first two tiles matter.
    is_two: bool,
    /// If the meld is made public. All melds in a hand must be publicized to win.
    made_public: bool = false,

    /// Attempt to make a meld of 3 tiles.
    pub fn tryMakeMeld(allocator: std.mem.Allocator, tiles: [MELD_SIZE]tile.Tile, force_orientation: bool, allow_different_winds: bool, allow_different_dragons: bool, allow_wildcards: bool) !?Self {

        // Wildcards suck so remove them from consideration entirely. Also make sure we can actually form a meld while we are at it.
        var to_check: [MELD_SIZE]tile.Tile = [_]tile.Tile{tile.Tile{}} ** MELD_SIZE;
        var to_check_len: u4 = 0;
        for (tiles) |curr_tile| {
            if (!curr_tile.isMeldable())
                return null;
            if (curr_tile.powerUpType(allow_wildcards, allow_wildcards) == .Wildcard)
                continue;
            to_check[to_check_len] = curr_tile;
            to_check_len += 1;
        }

        // Return value in case it succeeds.
        const ret = Self{
            .tiles = tiles,
            .is_two = false,
            .made_public = false,
        };

        // If 2+ are wildcards then automatic meld.
        if (to_check_len < 2)
            return ret;

        // Not legal to mix and match type.
        const tile_type = to_check[0].tile_type;
        for (to_check[1..to_check_len]) |curr_tile| {
            if (tile_type != curr_tile.tile_type)
                return null;
        }

        // Force orientation rules if that's a thing that happens.
        if (force_orientation) {
            const upside_down = to_check[0].upside_down;
            for (to_check[1..to_check_len]) |curr_tile| {
                if (upside_down != curr_tile.upside_down)
                    return null;
            }
        }

        // Easy case. All the same tile, guaranteed meld.
        const first_number = to_check[0].number;
        for (to_check[1..to_check_len]) |curr_tile| {
            if (first_number != curr_tile.number)
                break;
        } else return ret;

        // Need to sort check list for sequence in order of increasing number. Need to make sure to ignore upside-down.
        std.mem.sort(tile.Tile, to_check[0..to_check_len], false, tile.Tile.lessThan);

        // Is a valid sequence?
        if (to_check[0].isMeldSequenceable()) {
            for (1..to_check_len) |ind| {
                if (to_check[ind - 1].number + 1 != to_check[ind].number)
                    break;
            } else return ret;

            // Edge case, 1 wildcard covers the gap between a sequence. Assert is because algorithm assumes 3 in a meld.
            std.debug.assert(MELD_SIZE == 3);
            if (to_check_len == 2) {
                if (to_check[0].number + 2 == to_check[1].number)
                    return ret;
            }
        }

        // Different combo of winds or dragons?
        if ((allow_different_winds and tile_type == .Wind) or (allow_different_dragons and tile_type == .Dragon)) {
            var existing_nums = std.AutoHashMap(u4, void).init(allocator);
            defer existing_nums.deinit();
            for (to_check[0..to_check_len]) |curr_tile| {
                const v = try existing_nums.getOrPut(curr_tile.number);
                if (v.found_existing)
                    break;
            } else return ret;
        }

        // Is just garbage.
        return null;
    }

    /// Try making a meld of two tiles. Note that this should only be called if the player only has two tiles left.
    pub fn tryMakeMeldPair(tiles: [2]tile.Tile, force_orientation: bool, allow_wildcards: bool) ?Self {
        const ret = Self{
            .tiles = [MELD_SIZE]tile.Tile{ tiles[0], tiles[1], tile.Tile{} },
            .is_two = true,
            .made_public = false,
        };

        if (!tiles[0].isMeldable() or !tiles[1].isMeldable())
            return null;
        if (tiles[0].powerUpType(allow_wildcards, allow_wildcards) == .Wildcard or tiles[1].powerUpType(allow_wildcards, allow_wildcards) == .Wildcard)
            return ret;
        if (tiles[0].tile_type == tiles[1].tile_type and tiles[0].number == tiles[1].number and (if (force_orientation) (tiles[0].upside_down == tiles[1].upside_down) else true))
            return ret;
        return null;
    }
};

test "Meld" {

    // Identical tiles.
    try std.testing.expect(Meld.tryMakeMeldPair([2]tile.Tile{ .{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = false,
    }, .{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = true,
    } }, false, false) != null);

    // Enforce orientation rules.
    try std.testing.expect(Meld.tryMakeMeldPair([2]tile.Tile{ .{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = false,
    }, .{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = true,
    } }, true, false) == null);

    // Different numbers.
    try std.testing.expect(Meld.tryMakeMeldPair([2]tile.Tile{ .{
        .tile_type = .Bamboo,
        .number = 2,
        .upside_down = true,
    }, .{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = true,
    } }, true, false) == null);

    // Not meldable.
    try std.testing.expect(Meld.tryMakeMeldPair([2]tile.Tile{ .{
        .tile_type = .Flower1,
        .number = 3,
        .upside_down = false,
    }, .{
        .tile_type = .Flower1,
        .number = 3,
        .upside_down = false,
    } }, false, false) == null);

    // Wildcard with not meldable.
    try std.testing.expect(Meld.tryMakeMeldPair([2]tile.Tile{ .{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.West),
        .upside_down = false,
    }, .{
        .tile_type = .Flower1,
        .number = 3,
        .upside_down = false,
    } }, false, true) == null);

    // Wildcard with meldable.
    try std.testing.expect(Meld.tryMakeMeldPair([2]tile.Tile{ .{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.West),
        .upside_down = false,
    }, .{
        .tile_type = .Dot,
        .number = 1,
        .upside_down = false,
    } }, false, true) != null);

    // Allocation fails with differing winds.
    try std.testing.expectError(error.OutOfMemory, Meld.tryMakeMeld(std.testing.failing_allocator, [MELD_SIZE]tile.Tile{ .{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.North),
        .upside_down = false,
    }, .{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.East),
        .upside_down = true,
    }, .{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.South),
        .upside_down = true,
    } }, false, true, false, false));

    // All 3 match.
    const bamboo3_up = tile.Tile{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = false,
    };
    const bamboo3_down = tile.Tile{
        .tile_type = .Bamboo,
        .number = 3,
        .upside_down = true,
    };
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ bamboo3_up, bamboo3_down, bamboo3_up }, false, false, false, false), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ bamboo3_up, bamboo3_down, bamboo3_up },
        .is_two = false,
    }));

    // One doesn't match of 3.
    const bamboo2_up = tile.Tile{
        .tile_type = .Bamboo,
        .number = 2,
        .upside_down = false,
    };
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ bamboo3_up, bamboo3_down, bamboo3_up }, true, false, false, false) == null);
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ bamboo3_up, bamboo2_up, bamboo3_up }, true, false, false, false) == null);

    // Sequence but wrong orientation.
    const dot7 = tile.Tile{
        .tile_type = .Dot,
        .number = 7,
        .upside_down = false,
    };
    const dot8 = tile.Tile{
        .tile_type = .Dot,
        .number = 8,
        .upside_down = false,
    };
    const dot9_up = tile.Tile{
        .tile_type = .Dot,
        .number = 9,
        .upside_down = false,
    };
    const dot9_down = tile.Tile{
        .tile_type = .Dot,
        .number = 9,
        .upside_down = true,
    };
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ dot7, dot8, dot9_down }, true, false, false, false) == null);

    // Sequence.
    const dot1 = tile.Tile{
        .tile_type = .Dot,
        .number = 1,
        .upside_down = false,
    };
    const dot2 = tile.Tile{
        .tile_type = .Dot,
        .number = 2,
        .upside_down = false,
    };
    const dot3 = tile.Tile{
        .tile_type = .Dot,
        .number = 3,
        .upside_down = false,
    };
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ dot1, dot2, dot3 }, false, false, false, false), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ dot1, dot2, dot3 },
        .is_two = false,
    }));
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ dot9_up, dot7, dot8 }, false, false, false, false), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ dot9_up, dot7, dot8 },
        .is_two = false,
    }));

    // Sequence but with wildcard.
    const wildcard = tile.Tile{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.West),
        .upside_down = false,
    };
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ dot1, wildcard, dot3 }, false, false, false, true), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ dot1, wildcard, dot3 },
        .is_two = false,
    }));

    // One wildcard.
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ dot9_down, wildcard, dot9_up }, false, false, false, true), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ dot9_down, wildcard, dot9_up },
        .is_two = false,
    }));

    // Two wildcards.
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ wildcard, dot1, wildcard }, false, false, false, true), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ wildcard, dot1, wildcard },
        .is_two = false,
    }));

    // Two wildcards and non-meldable.
    const flower1 = tile.Tile{
        .tile_type = .Flower1,
        .number = 1,
        .upside_down = false,
    };
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ wildcard, flower1, wildcard }, false, false, false, true) == null);

    // Differing winds allowed or not
    const north = tile.Tile{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.North),
        .upside_down = false,
    };
    const east = tile.Tile{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.East),
        .upside_down = false,
    };
    const south = tile.Tile{
        .tile_type = .Wind,
        .number = @intFromEnum(tile.WindType.South),
        .upside_down = false,
    };
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ north, east, south }, false, true, false, false), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ north, east, south },
        .is_two = false,
    }));
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ north, east, east }, false, true, false, false) == null);
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ north, east, south }, false, false, false, false) == null);

    // Differing dragons not allowed or not.
    const red = tile.Tile{
        .tile_type = .Dragon,
        .number = @intFromEnum(tile.DragonType.Red),
        .upside_down = false,
    };
    const green = tile.Tile{
        .tile_type = .Dragon,
        .number = @intFromEnum(tile.DragonType.Green),
        .upside_down = false,
    };
    const white = tile.Tile{
        .tile_type = .Dragon,
        .number = @intFromEnum(tile.DragonType.White),
        .upside_down = false,
    };
    try std.testing.expect(std.meta.eql(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ red, green, white }, false, false, true, false), Meld{
        .tiles = [MELD_SIZE]tile.Tile{ red, green, white },
        .is_two = false,
    }));
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ green, white, green }, false, false, true, false) == null);
    try std.testing.expect(try Meld.tryMakeMeld(std.testing.allocator, [MELD_SIZE]tile.Tile{ red, green, white }, false, false, false, false) == null);
}
