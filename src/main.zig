const rl = @import("raylib");
const std = @import("std");
const perlin = @import("perlinNoise.zig");
pub fn initBordRectangles(allocator: std.mem.Allocator, height: u32, width: u32, size: u8) ![][]rl.Rectangle {
    const errors = error{ InvalidHeight, InvalidWidth };

    if (height > rl.getMonitorHeight(rl.getCurrentMonitor())) {
        return errors.InvalidHeight;
    }

    if (height == 0) {
        return errors.InvalidHeight;
    }

    if (width > rl.getMonitorWidth(rl.getCurrentMonitor())) {
        return errors.InvalidWidth;
    }

    if (width == 0) {
        return errors.InvalidWidth;
    }

    //return slice of rectangle
    var board = try allocator.alloc([]rl.Rectangle, height);

    //initialize slice
    for (0..height) |i| {
        board[i] = try allocator.alloc(rl.Rectangle, width);
        for (0..width) |j| {
            board[i][j] = rl.Rectangle{
                .x = @floatFromInt(j * size),
                .y = @floatFromInt(i * size),
                .width = @floatFromInt(size),
                .height = @floatFromInt(size),
            };
        }
    }
    return board;
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------

    rl.initWindow(500, 500, "raylib-zig [core] example - basic window");
    rl.toggleFullscreen();

    const screenWidth: u32 = @intCast(rl.getMonitorWidth(rl.getCurrentMonitor()));
    const screenHeight: u32 = @intCast(rl.getMonitorHeight(rl.getCurrentMonitor()));

    std.debug.print(
        "width={}\nheight={}\n",
        .{ screenWidth, screenHeight },
    );

    const rectSize: u32 = 10;
    const squaresPerLat: u8 = 10;

    const boardWidth = screenWidth / rectSize;
    const boardHeight = screenHeight / rectSize;

    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const rectangles = try initBordRectangles(gpa.allocator(), boardHeight, boardWidth, rectSize);
    const noise = try perlin.generatePerlinNoise(gpa.allocator(), boardHeight, boardWidth, squaresPerLat, @as(u64, @intCast(std.time.microTimestamp())));

    defer {
        for (rectangles) |row| {
            gpa.allocator().free(row);
        }
        gpa.allocator().free(rectangles);
    }

    defer {
        for (noise) |row| {
            gpa.allocator().free(row);
        }
        gpa.allocator().free(noise);
    }

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        rl.beginDrawing();
        defer rl.endDrawing();

        const colors = [_]rl.Color{ rl.Color.red, rl.Color.green, rl.Color.blue };
        for (0..boardHeight) |i| {
            for (0..boardWidth) |j| {
                if (noise[i][j] > 0.2 * 3) {
                    rl.drawRectangleRec(rectangles[i][j], colors[0]);
                } else if (noise[i][j] > 0.05 * 3) {
                    rl.drawRectangleRec(rectangles[i][j], colors[1]);
                } else {
                    rl.drawRectangleRec(rectangles[i][j], colors[2]);
                }

                //noise[i][j] = noise[i][j] + 0.01;
                //if (noise[i][j] > 0.4) {
                //    noise[i][j] = 0;
                //}
            }
        }
        //----------------------------------------------------------------------------------
    }
}
