const rl = @import("raylib");
const std = @import("std");
const random = std.Random;

fn randomGradient(rng: anytype) rl.Vector2 {
    const theta = rng.float(f32) * 2.0 * std.math.pi;
    return .{
        .x = @cos(theta),
        .y = @sin(theta),
    };
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    //linear interpilation math
    return a + t * (b - a);
}

fn fade(t: f32) f32 {
    //magic fade math
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

pub fn getNoiseStandardDeviation(noise: [][]f32) f32 {
    var standardDev = 0;
    const mean = getNoiseMean(noise);
    for (noise) |row| {
        for (row) |col| {
            standardDev += @exp2(col - mean);
        }
    }

    standardDev /= (noise.len * noise[0].len);
    return @sqrt(standardDev);
}

pub fn getNoiseMean(noise: [][]f32) f32 {
    var mean: f32 = 0;
    for (noise) |row| {
        for (row) |col| {
            mean += col;
        }
    }

    return mean / (noise.len * noise[0].len);
}

pub fn getNoisePercentile(noise: [][]f32, percentileDecimal: f32) f32 {
    const buckets = 1024;
    //initializes an array of usize length buckets. element at 0 = 0 ** number of buckets
    //this initializes the array to have all zeros
    var hist: [buckets]usize = [_]usize{0} ** buckets;

    for (noise) |row| {
        for (row) |value| {
            var idx: usize = @intFromFloat(value * buckets);
            if (idx >= buckets) idx = buckets - 1;
            hist[idx] += 1;
        }
    }

    const target = (noise.len * noise[0].len) * percentileDecimal;
    var running: usize = 0;
    var cutoffBucket: usize = 0;

    for (hist, 0..) |count, i| {
        running += count;
        if (running >= target) {
            cutoffBucket = i;
            break;
        }
    }

    return @as(f32, @floatFromInt(cutoffBucket)) / buckets;
}

pub fn generatePerlinNoise(allocator: std.mem.Allocator, height: u32, width: u32, squaresPerLat: u16, seed: u64) ![][]f32 {
    const errors = error{ InvalidHeight, InvalidWidth, InvalidSquaresPerLat };
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

    if (squaresPerLat == 0) {
        return errors.InvalidSquaresPerLat;
    }

    const spl: u32 = @intCast(squaresPerLat);
    //lattice height and width is the celing devision of screen squares/squares per lattice
    //this covers the case where we actually need an extra lattice
    const latticeHeight = (height + spl - 1) / spl;
    const latticeWidth = (width + spl - 1) / spl;

    //this is the lattice for our squares
    var latticeVectors = try allocator.alloc([]rl.Vector2, latticeHeight + 1);

    defer {
        for (latticeVectors) |row| {
            allocator.free(row);
        }

        allocator.free(latticeVectors);
    }

    var prng = random.DefaultPrng.init(seed);
    const rng = prng.random();

    //initialize the random gradients
    for (0..latticeHeight + 1) |i| {
        latticeVectors[i] = try allocator.alloc(rl.Vector2, latticeWidth + 1);

        for (0..latticeWidth + 1) |j| {
            latticeVectors[i][j] = randomGradient(rng);
        }
    }

    var squareNoise = try allocator.alloc([]f32, height);
    //big generate perlin noise step
    for (0..height) |i| {
        squareNoise[i] = try allocator.alloc(f32, width);
        for (0..width) |j| {
            //calculate the current lattice square we are in
            const latticeI = i / spl;
            const latticeJ = j / spl;

            //calculate the squares print position within the lattice square
            const localI = i % spl;
            const localJ = j % spl;

            //our squares are unit squares. So the center of one square is sqrt(0.5 * 0.5)
            const fy = (@as(f32, @floatFromInt(localI)) + 0.5) / @as(f32, @floatFromInt(spl));
            const fx = (@as(f32, @floatFromInt(localJ)) + 0.5) / @as(f32, @floatFromInt(spl));

            const blVect = rl.Vector2.init(fx, fy);
            const brVect = rl.Vector2.init(fx - 1.0, fy);
            const tlVect = rl.Vector2.init(fx, fy - 1.0);
            const trVect = rl.Vector2.init(fx - 1.0, fy - 1.0);

            //get the dot product of the gradients and the distances
            const dotbl = latticeVectors[latticeI][latticeJ].dotProduct(blVect);
            const dotbr = latticeVectors[latticeI][latticeJ + 1].dotProduct(brVect);
            const dottl = latticeVectors[latticeI + 1][latticeJ].dotProduct(tlVect);
            const dottr = latticeVectors[latticeI + 1][latticeJ + 1].dotProduct(trVect);

            const u = fade(fx);
            const v = fade(fy);
            const ix0 = lerp(dotbl, dotbr, u);
            const ix1 = lerp(dottl, dottr, u);
            const value = lerp(ix0, ix1, v);

            //normalized to [0, 1]
            squareNoise[i][j] = (value + 1.0) * 0.5;
        }
    }

    return squareNoise;
}
