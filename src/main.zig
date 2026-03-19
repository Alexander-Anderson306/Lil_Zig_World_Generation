const rl = @import("raylib");
const std = @import("std");
const prl = @import("perlinNoise.zig");
const tg = @import("terrainGeneration.zig");

pub fn main() !void {
    rl.initWindow(500, 500, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    rl.toggleFullscreen();

    const blockSize: u16 = 5;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var terrain = try tg.Terrain.init(allocator, blockSize);
    defer terrain.deinit();

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        terrain.displayTerrain();
    }
}
