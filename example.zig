const std = @import("std");
const gltf = @import("./gltf.zig");
const json = gltf.json;

pub const main = if (@import("builtin").cpu.arch != .wasm32) mainNative else mainDummy;

fn mainNative() !void {
    //@setEvalBranchQuota(5000);
    const alloc = std.heap.page_allocator;
    const options = json.ParseOptions{
        .allocator = alloc,
        .duplicate_field_behavior = .Error,
    };

    const src = try std.fs.cwd().readFileAlloc(alloc, "level1.gltf", 40 * 1024);

    const parsed = try json.parse(gltf.glTF, &json.TokenStream.init(src), options, null);
    defer json.parseFree(gltf.glTF, parsed, options);

    std.debug.warn("parsed value: {}\n\n", .{parsed});
}

fn mainDummy() void {}

pub export fn mainWeb() usize {
    @setEvalBranchQuota(5000);
    const alloc = std.heap.page_allocator;
    const options = json.ParseOptions{
        .allocator = alloc,
        .duplicate_field_behavior = .Error,
    };

    const src = @embedFile("level1.gltf");

    const parsed = json.parse(gltf.glTF, &json.TokenStream.init(src), options, null) catch unreachable;
    defer json.parseFree(gltf.glTF, parsed, options);

    return parsed.nodes.len;
}
