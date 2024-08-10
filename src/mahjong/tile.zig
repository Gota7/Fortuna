const std = @import("std");

const PRICE_NORMAL = 2;
const PRICE_POWER = 3;
const PRICE_WILDCARD = 4;

/// Type of tile.
pub const TileType = enum {
    Number,
    Bamboo,
    Dot,
    Wind,
    Dragon,
    Flower1,
    Flower2,
    Toxic,
    Invalid,
};

/// Wind direction.
pub const WindType = enum {
    North,
    East,
    South,
    West,
};

/// Type of dragon.
pub const DragonType = enum {
    Red,
    Green,
    White,
};

/// Power-up type.
pub const PowerUpType = enum {
    None,
    Know,
    Reverse,
    Skip,
    Wildcard,
    Trade,
    Flip,
    Pick,
};

/// Mahjong tile.
pub const Tile = struct {
    const Self = @This();
    /// Type of tile in use.
    tile_type: TileType = .Invalid,
    /// Either variant or numeric amount of the tile.
    number: u4 = 0,
    /// If the tile is upside-down.
    upside_down: bool = false,

    /// Flip the tile's upside-down-ness.
    pub fn flip(self: *Self) void {
        self.upside_down = !self.upside_down;
    }

    /// If the tile can be used to potentially form a meld.
    pub fn isMeldable(self: Tile) bool {
        return self.tile_type == .Number or self.tile_type == .Bamboo or self.tile_type == .Dot or self.tile_type == .Wind or self.tile_type == .Dragon;
    }

    /// If the tile can be in a meld that has incrementing numbers.
    pub fn isMeldSequenceable(self: Self) bool {
        return self.tile_type == .Number or self.tile_type == .Bamboo or self.tile_type == .Dot;
    }

    /// If the tile has monetary value.
    pub fn isMoney(self: Self) bool {
        return self.tile_type == .Flower1 or self.tile_type == .Flower2;
    }

    /// If the tile can be considered a power-up. Parameters determine if wind and/or dragon types count as power-ups.
    pub fn isPowerUp(self: Self, include_wind: bool, include_dragon: bool) bool {
        if (include_wind and self.tile_type == .Wind)
            return true;
        if (include_dragon and self.tile_type == .Dragon)
            return true;
        return false;
    }

    /// Get tile less than another. Sorts in priority: Upside-down < Rightside-up, Type, Number.
    pub fn lessThan(ignore_upside_down: bool, lhs: Self, rhs: Self) bool {
        if (!ignore_upside_down and lhs.upside_down != rhs.upside_down)
            return lhs.upside_down;
        if (@intFromEnum(lhs.tile_type) < @intFromEnum(rhs.tile_type))
            return true;
        if (lhs.number < rhs.number)
            return true;
        return false;
    }

    /// The money amount of the tile, is 0 for invalid money tiles.
    pub fn moneyAmount(self: Self) u4 {
        if (isMoney(self)) {
            return self.number;
        } else return 0;
    }

    /// The type of power-up for the tile. Parameters indicate whether or not wind and/or dragon types count as power-ups. Power-up returned may be none.
    pub fn powerUpType(self: Self, include_wind: bool, include_dragon: bool) PowerUpType {
        if (self.tile_type == .Wind and include_wind) {
            const wind_enum: WindType = @enumFromInt(self.number);
            return switch (wind_enum) {
                .North => .Know,
                .East => .Reverse,
                .South => .Skip,
                .West => .Wildcard,
            };
        } else if (self.tile_type == .Dragon and include_dragon) {
            const dragon_enum: DragonType = @enumFromInt(self.number);
            return switch (dragon_enum) {
                .Red => .Trade,
                .Green => .Flip,
                .White => .Pick,
            };
        } else return .None;
    }

    /// The price of the tile to buy from the shop. Parameters are whether wind and/or dragon types count as power-ups.
    pub fn price(self: Self, include_wind: bool, include_dragon: bool) u4 {
        const power_up = self.powerUpType(include_wind, include_dragon);
        if (power_up == .Wildcard) return PRICE_WILDCARD;
        if (power_up != .None) return PRICE_POWER;
        return PRICE_NORMAL;
    }

    /// Randomly spin the tile to determine if it is upside-down or not.
    pub fn randomlySpin(self: *Self, random: std.rand.Random) void {
        self.upside_down = random.boolean();
    }
};
