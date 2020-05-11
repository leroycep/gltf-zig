const std = @import("std");
const gltf = @import("./gltf.zig");
const json = gltf.json;

//const ParseOverride = struct {
//    pub fn overridesType(comptime T: type) bool {
//        return T == gltf.Scene;
//    }
//
//    pub fn parseJson(comptime T: type, token: json.Token, tokens: *json.TokenStream, options: json.ParseOptions) !T {
//        std.debug.assert(T == gltf.Scene);
//        return gltf.Scene{
//            .nodes = try std.mem.dupe(options.allocator.?, usize, &[_]usize{}),
//            .name = try std.mem.dupe(options.allocator.?, u8, "Hello, world!"),
//        };
//    }
//};

pub fn main() !void {
    @setEvalBranchQuota(5000);
    const alloc = std.heap.page_allocator;
    const options = json.ParseOptions{
        .allocator = alloc,
        .duplicate_field_behavior = .Error,
    };

    const parsedScene = try json.parse(gltf.Scene, &json.TokenStream.init(
        \\{
        \\  "name": "Scene",
        \\  "nodes": [0]
        \\}
    ), options, null);
    defer json.parseFree(gltf.Scene, parsedScene, options);
    std.debug.warn("parsed Scene: {}\n\n", .{parsedScene});

    const parsedNode = try json.parse(gltf.Node, &json.TokenStream.init(
        \\{
        \\    "mesh" : 0,
        \\    "name" : "terrain"
        \\}
    ), options, null);
    defer json.parseFree(gltf.Node, parsedNode, options);
    std.debug.warn("parsed Node: {}\n\n", .{parsedNode});

    const parsedMaterial = try json.parse(gltf.Material, &json.TokenStream.init(
        \\        {
        \\            "alphaCutoff" : 0,
        \\            "alphaMode" : "MASK",
        \\            "doubleSided" : true,
        \\            "emissiveFactor" : [
        \\                1,
        \\                1,
        \\                1
        \\            ],
        \\            "emissiveTexture" : {
        \\                "index" : 0,
        \\                "texCoord" : 0
        \\            },
        \\            "name" : "tiles",
        \\            "pbrMetallicRoughness" : {}
        \\        }
    ), options, null);
    defer json.parseFree(gltf.Material, parsedMaterial, options);
    std.debug.warn("parsed Material: {}\n\n", .{parsedMaterial});

    const parsedMesh = try json.parse(gltf.Mesh, &json.TokenStream.init(
        \\        {
        \\            "name" : "Plane",
        \\            "primitives" : [
        \\                {
        \\                    "attributes" : {
        \\                        "POSITION" : 0,
        \\                        "NORMAL" : 1,
        \\                        "TEXCOORD_0" : 2
        \\                    },
        \\                    "indices" : 3,
        \\                    "material" : 0
        \\                }
        \\            ]
        \\        }
    ), options, null);
    defer json.parseFree(gltf.Mesh, parsedMesh, options);
    std.debug.warn("parsed Mesh: {}\n\n", .{parsedMesh});

    const parsed = try json.parse(gltf.glTF, &json.TokenStream.init(src), options, null);
    defer json.parseFree(gltf.glTF, parsed, options);
    std.debug.warn("parsed value: {}\n\n", .{parsed});
    for (parsed.meshes) |mesh| {
        var iter = mesh.primitives[0].attributes.map.iterator();
        while (iter.next()) |attrib| {
            std.debug.warn("attrib: {} {}\n", .{ attrib.key, attrib.value });
        }
    }

    const emptyGLTF = try json.parse(gltf.glTF, &json.TokenStream.init(
        \\ { "asset": {"version": "120" } }
    ), options, null);
    defer json.parseFree(gltf.glTF, emptyGLTF, options);
    std.debug.warn("emptyGLTF value: {}\n\n", .{emptyGLTF});

    var parseErrorInfo: json.ParseErrorInfo = .None;
    testblock: {
        const brokenJsonTest = json.parse(gltf.glTF, &json.TokenStream.init(
            \\ { "asset": {"version": "120" }, "hello": "world" }
        ), options, &parseErrorInfo) catch |err| {
            std.debug.assert(err == error.UnknownField);
            std.debug.warn("parseErrorInfo: {}\n\n", .{parseErrorInfo});
            break :testblock;
        };
    }

    testblock: {
        const missingFieldTest = json.parse(gltf.glTF, &json.TokenStream.init(
            \\ { }
        ), options, &parseErrorInfo) catch |err| {
            std.debug.assert(err == error.MissingField);
            std.debug.warn("parseErrorInfo: {}\n\n", .{parseErrorInfo});
            break :testblock;
        };
    }
}

const src =
    \\{
    \\    "asset" : {
    \\        "generator" : "Khronos glTF Blender I/O v1.1.46",
    \\        "version" : "2.0"
    \\    },
    \\    "scene" : 0,
    \\    "scenes" : [
    \\        {
    \\            "name" : "Scene",
    \\            "nodes" : [
    \\                0
    \\            ]
    \\        }
    \\    ],
    \\    "nodes" : [
    \\        {
    \\            "mesh" : 0,
    \\            "name" : "terrain"
    \\        }
    \\    ],
    \\    "materials" : [
    \\        {
    \\            "alphaCutoff" : 0,
    \\            "alphaMode" : "MASK",
    \\            "doubleSided" : true,
    \\            "emissiveFactor" : [
    \\                1,
    \\                1,
    \\                1
    \\            ],
    \\            "emissiveTexture" : {
    \\                "index" : 0,
    \\                "texCoord" : 0
    \\            },
    \\            "name" : "tiles",
    \\            "pbrMetallicRoughness" : {}
    \\        }
    \\    ],
    \\    "meshes" : [
    \\        {
    \\            "name" : "Plane",
    \\            "primitives" : [
    \\                {
    \\                    "attributes" : {
    \\                        "POSITION" : 0,
    \\                        "NORMAL" : 1,
    \\                        "TEXCOORD_0" : 2
    \\                    },
    \\                    "indices" : 3,
    \\                    "material" : 0
    \\                }
    \\            ]
    \\        }
    \\    ],
    \\    "textures" : [
    \\        {
    \\            "sampler" : 0,
    \\            "source" : 0
    \\        }
    \\    ],
    \\    "images" : [
    \\        {
    \\            "mimeType" : "image/png",
    \\            "name" : "tiles",
    \\            "uri" : "textures/tiles.png"
    \\        }
    \\    ],
    \\    "accessors" : [
    \\        {
    \\            "bufferView" : 0,
    \\            "componentType" : 5126,
    \\            "count" : 4696,
    \\            "max" : [
    \\                16,
    \\                3,
    \\                10
    \\            ],
    \\            "min" : [
    \\                -16,
    \\                0,
    \\                -10
    \\            ],
    \\            "type" : "VEC3"
    \\        },
    \\        {
    \\            "bufferView" : 1,
    \\            "componentType" : 5126,
    \\            "count" : 4696,
    \\            "type" : "VEC3"
    \\        },
    \\        {
    \\            "bufferView" : 2,
    \\            "componentType" : 5126,
    \\            "count" : 4696,
    \\            "type" : "VEC2"
    \\        },
    \\        {
    \\            "bufferView" : 3,
    \\            "componentType" : 5123,
    \\            "count" : 7044,
    \\            "type" : "SCALAR"
    \\        }
    \\    ],
    \\    "bufferViews" : [
    \\        {
    \\            "buffer" : 0,
    \\            "byteLength" : 56352,
    \\            "byteOffset" : 0
    \\        },
    \\        {
    \\            "buffer" : 0,
    \\            "byteLength" : 56352,
    \\            "byteOffset" : 56352
    \\        },
    \\        {
    \\            "buffer" : 0,
    \\            "byteLength" : 37568,
    \\            "byteOffset" : 112704
    \\        },
    \\        {
    \\            "buffer" : 0,
    \\            "byteLength" : 14088,
    \\            "byteOffset" : 150272
    \\        }
    \\    ],
    \\    "samplers" : [
    \\        {
    \\            "magFilter" : 9728,
    \\            "minFilter" : 9984
    \\        }
    \\    ],
    \\    "buffers" : [
    \\        {
    \\            "byteLength" : 164360,
    \\            "uri" : "level1.bin"
    \\        }
    \\    ]
    \\}
;
