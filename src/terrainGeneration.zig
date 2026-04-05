const rl = @import("raylib");
const std = @import("std");
const pln = @import("perlinNoise.zig");

//this struct represents the terrain map that is generated
pub const Terrain = struct {
    allocator: std.mem.Allocator,
    blockSize: u16,
    blocks: [][]Block,
    seaLevelCutoff: f32,
    seed: u64,

    fn nextSeed(self: *Terrain) u64 {
        self.seed += 1;
        return self.seed;
    }

    //this struct represents an individual terrain block
    const Block = struct { color: rl.Color, elevation: f32, temperature: f32, humidity: f32 };

    pub fn init(allocator: std.mem.Allocator, blockSize: u16, seed: u64) !Terrain {
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
            .seaLevelCutoff = 0,
            .seed = seed,
        };

        //call generateSeaLevel), generateelevation(), and generateHumidity() here
        try terrain.generateSeaLevel();
        try terrain.assignBiome();

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
        const sparseLattice: u16 = @intCast(self.blocks.len / 45); //32
        const medLattice: u16 = @intCast(self.blocks.len / 12); //6
        const denseLattice: u16 = @intCast(self.blocks.len / 3); //2

        //increment seed after every use
        const noise1 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), denseLattice, self.nextSeed());
        errdefer {
            for (noise1) |row| self.allocator.free(row);
            self.allocator.free(noise1);
        }
        const noise2 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), medLattice, self.nextSeed());
        errdefer {
            for (noise2) |row| self.allocator.free(row);
            self.allocator.free(noise2);
        }
        const noise3 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), sparseLattice, self.nextSeed());
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

        //use a 3/5 percentile
        self.seaLevelCutoff = pln.getNoisePercentile(combinedNoise, (3.0 / 5.0));

        for (0..self.blocks.len) |i| {
            for (0..self.blocks[i].len) |j| {
                self.blocks[i][j].elevation = combinedNoise[i][j];
            }
        }

        return;
    }

    fn generateElevation(self: *Terrain) !void {
        //generate for now two layers of noise for general elivation
        //only apply noise to terrain thats above sea level
        //then use some sort of random curve drawing algorithm
        //draw a curve on the map with something like a sine wave at an angle
        //randomly select magnitude of hight
        //use some distrobution function that makes the middle of the curve the highest values.
        //if mountain ranges spawn underwater we can make the center of the range an island volcano easy fix

        //generate two layers of perlin noise
        //first layer is general elivation
        //second layer is for local hills

        const latticeSize1: u16 = @intCast(self.blocks.len / 4);
        const latticeSize2: u16 = @intCast(self.blocks.len / 32);

        const noise1 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), latticeSize1, self.nextSeed());
        const noise2 = try pln.generatePerlinNoise(self.allocator, @intCast(self.blocks.len), @intCast(self.blocks[0].len), latticeSize2, self.nextSeed());

        defer {
            for (noise1) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(noise1);

            for (noise2) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(noise2);
        }

        const elivationNoise: [][]f32 = try self.allocator.alloc([]f32, self.blocks.len);
        for (elivationNoise) |*row| {
            row.* = try self.allocator.alloc(f32, self.blocks[0].len);
        }

        defer {
            for (elivationNoise) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(elivationNoise);
        }

        for (0..elivationNoise.len) |i| {
            for (0..elivationNoise[i].len) |j| {
                elivationNoise[i][j] = (noise1[i][j] * 0.8) + (noise2[i][j] * 0.2);
            }
        }

        //we should normalize the noise to -0.5 and 0.5 so that we can raise and lower elivation
        //make sure that elivation does not dip below sea level
        return;
    }

    fn applyTemperature(self: *Terrain) !void {
        _ = self;
        return;
    }

    fn generateHumidity(self: *Terrain) !void {
        _ = self;
        return;
    }

    fn assignBiome(self: *Terrain) !void {
        for (self.blocks) |row| {
            for (row) |*block| {
                if (block.elevation > self.seaLevelCutoff) {
                    block.color = rl.Color.green;
                } else {
                    block.color = rl.Color.dark_blue;
                }
            }
        }
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
