const rl = @import("raylib");
const std = @import("std");
const pln = @import("perlinNoise.zig");

//this struct represents the terrain map that is generated
pub const Terrain = struct {
    allocator: std.mem.Allocator,
    blockSize: u16,
    blocks: [][]Block,

    //this struct represents an individual terrain block
    const Block = struct { color: rl.Color, elevation: f32, temperature: f32, humidity: f32 };

    pub fn init(allocator: std.mem.Allocator, blockSize: u16) !Terrain {
        const screenHeight = rl.getRenderHeight();
        const screenWidth = rl.getRenderWidth();

        const blocksHeight: usize = @intCast(@divFloor(screenHeight, @as(i32, @intCast(blockSize))));
        const blocksWidth: usize = @intCast(@divFloor(screenWidth, @as(i32, @intCast(blockSize))));

        //alloc blocks here
        const blocks = try allocator.alloc([]Block, blocksHeight);
        for (blocks) |*row| {
            row.* = try allocator.alloc(Block, blocksWidth);
        }

        var terrain = Terrain{
            .allocator = allocator,
            .blockSize = blockSize,
            .blocks = blocks,
        };

        //call generateSeaLevel), generateelevation(), and generateHumidity() here
        try terrain.generateSeaLevel();

        return terrain;
    }

    pub fn deinit(self: *Terrain) void {
        for (self.blocks) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.blocks);
    }

    fn generateSeaLevel(self: *Terrain) !void {
        //density sizes of the noise
        const sparseLattice: u16 = @intCast(self.blocks.len / 32);
        const medLattice: u16 = @intCast(self.blocks.len / 6);
        const denseLattice: u16 = @intCast(self.blocks.len / 2);

        const noise1 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), denseLattice, @intCast(std.time.microTimestamp()));
        errdefer {
            for (noise1) |row| self.allocator.free(row);
            self.allocator.free(noise1);
        }
        const noise2 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), medLattice, @intCast(std.time.microTimestamp() + 1));
        errdefer {
            for (noise2) |row| self.allocator.free(row);
            self.allocator.free(noise2);
        }
        const noise3 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), sparseLattice, @intCast(std.time.microTimestamp() + 3));
        errdefer {
            for (noise3) |row| self.allocator.free(row);
            self.allocator.free(noise3);
        }

        //I may consider changing how noise is organized so I dont have to do this
        defer {
            for (noise1) |row| self.allocator.free(row);
            self.allocator.free(noise1);

            for (noise2) |row| self.allocator.free(row);
            self.allocator.free(noise2);

            for (noise3) |row| self.allocator.free(row);
            self.allocator.free(noise3);
        }

        //too lazy to do errdeffer with this code. its fineee
        const combinedNoise: [][]f32 = try self.allocator.alloc([]f32, self.blocks.len);

        for (combinedNoise) |*row| {
            row.* = try self.allocator.alloc(f32, self.blocks[0].len);
        }

        defer {
            for (combinedNoise) |row| self.allocator.free(row);
            self.allocator.free(combinedNoise);
        }

        for (0..combinedNoise.len) |i| {
            for (0..combinedNoise[i].len) |j| {
                combinedNoise[i][j] = 0;
                //mess with these values until i get a shape i want
                combinedNoise[i][j] += (noise1[i][j] * 0.7 + noise2[i][j] * 0.2 + noise3[i][j] * 0.1);
            }
        }

        //AI GENERATED CODE HERE, will go over tomorrow but im eepy
        const buckets = 1024;
        var hist: [buckets]usize = [_]usize{0} ** buckets;

        for (combinedNoise) |row| {
            for (row) |value| {
                var idx: usize = @intFromFloat(value * buckets);
                if (idx >= buckets) idx = buckets - 1;
                hist[idx] += 1;
            }
        }

        const target = (combinedNoise.len * combinedNoise[0].len) * 3 / 5;
        var running: usize = 0;
        var cutoff_bucket: usize = 0;

        for (hist, 0..) |count, i| {
            running += count;
            if (running >= target) {
                cutoff_bucket = i;
                break;
            }
        }

        const cutoff = @as(f32, @floatFromInt(cutoff_bucket)) / buckets;
        //END OF GENERATED CODE sorry world, but i was getting eepy

        for (0..self.blocks.len) |i| {
            for (0..self.blocks[i].len) |j| {
                //handle this tomorrow
                if (combinedNoise[i][j] > cutoff) {
                    //this is a land tile
                    self.blocks[i][j].color = rl.Color.green;
                } else {
                    //this is a ocean tile
                    self.blocks[i][j].color = rl.Color.blue;
                }

                self.blocks[i][j].elevation = combinedNoise[i][j];
            }
        }

        return;
    }

    fn generateElevation() !void {
        return;
    }

    fn generateHumidity() !void {
        return;
    }

    //draws the terrain to the screen
    pub fn displayTerrain(self: *Terrain) void {
        for (0..self.blocks.len) |i| {
            for (0..self.blocks[i].len) |j| {
                //draw this rectangle
                rl.drawRectangle(@intCast(j * self.blockSize), @intCast(i * self.blockSize), @intCast(self.blockSize), @intCast(self.blockSize), self.blocks[i][j].color);
            }
        }
        return;
    }
};
