const std = @import("std");
pub const json = @import("./json.zig");
const StringHashMap = std.StringHashMap;

fn Map(comptime T: type) type {
    return struct {
        map: StringHashMap(T),

        pub fn jsonParse(token: json.Token, tokens: *json.TokenStream, options: json.ParseOptions, parseErrorInfo: ?*json.ParseErrorInfo) !@This() {
            const allocator = options.allocator orelse return error.AllocatorRequired;
            var attribs = StringHashMap(T).init(allocator);
            errdefer attribs.deinit();

            switch (token) {
                .ObjectBegin => {},
                else => return error.UnexpectedToken,
            }

            while (true) {
                switch ((try tokens.next()) orelse return error.UnexpectedEndOfJson) {
                    .ObjectEnd => return @This(){ .map = attribs },
                    .String => |stringToken| {
                        const source_slice = stringToken.slice(tokens.slice, tokens.i - 1);
                        const property_name = switch (stringToken.escapes) {
                            .None => try std.mem.dupe(allocator, u8, source_slice),
                            .Some => |some_escapes| unescaping: {
                                const output = try allocator.alloc(u8, stringToken.decodedLength());
                                errdefer allocator.free(output);
                                try json.unescapeString(output, source_slice);
                                break :unescaping output;
                            },
                        };

                        const property_val = try json.parse(T, tokens, options, parseErrorInfo);

                        switch (options.duplicate_field_behavior) {
                            .UseFirst => {
                                var gop = try attribs.getOrPut(property_name);
                                if (gop.found_existing) {
                                    allocator.free(property_name);
                                    json.parseFree(T, property_val, options);
                                } else {
                                    gop.kv.value = property_val;
                                }
                            },
                            .Error => if (try attribs.put(property_name, property_val)) |prev_val| {
                                return error.DuplicateJSONField;
                            },
                            .UseLast => if (try attribs.put(property_name, property_val)) |prev| {
                                allocator.free(prev.key);
                                json.parseFree(T, prev.value, options);
                            },
                        }
                    },
                    else => return error.UnexpectedToken,
                }
            }
        }

        pub fn jsonParseFree(self: @This(), options: json.ParseOptions) void {
            var iter = self.map.iterator();
            while (iter.next()) |kv| {
                json.parseFree(T, kv.value, options);
                if (options.allocator) |alloc| {
                    alloc.free(kv.key);
                }
            }
            self.map.deinit();
        }
    };
}

pub const glTF = struct {
    extensionsUsed: [][]const u8 = &[_][]const u8{},
    extensionsRequired: [][]const u8 = &[_][]const u8{},
    accessors: []Accessor = &[_]Accessor{},
    //animations: []Animation,
    asset: Asset,
    buffers: []Buffer = &[_]Buffer{},
    bufferViews: []BufferView = &[_]BufferView{},
    //cameras: []Camera,
    images: []Image = &[_]Image{},
    materials: []Material = &[_]Material{},
    meshes: []Mesh = &[_]Mesh{},
    nodes: []Node = &[_]Node{},
    samplers: []Sampler = &[_]Sampler{},
    scene: ?usize = null,
    scenes: []Scene = &[_]Scene{},
    //skins: []Skin,
    textures: []Texture = &[_]Texture{},
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const BYTE = 5120;
pub const UNSIGNED_BYTE = 5121;
pub const SHORT = 5122;
pub const UNSIGNED_SHORT = 5123;
pub const UNSIGNED_INT = 5125;
pub const FLOAT = 5126;

/// A typed view into a bufferView. A bufferView contains raw binary data. An accessor provides a
/// typed view into a bufferView or a subset of a bufferView similar to how WebGL's
/// vertexAttribPointer() defines an attribute in a buffer.
pub const Accessor = struct {
    /// The index of the bufferView. When not defined, accessor must be initialized with zeros;
    /// sparse property or extensions could override zeros with actual values.
    bufferView: ?usize = null,

    /// The offset relative to the start of the bufferView in bytes. This must be a multiple of the
    /// size of the component datatype.
    byteOffset: usize = 0,

    /// The datatype of components in the attribute. All valid values correspond to WebGL enums. The
    /// corresponding typed arrays are Int8Array, Uint8Array, Int16Array, Uint16Array, Uint32Array,
    /// and Float32Array, respectively. 5125 (UNSIGNED_INT) is only allowed when the accessor
    /// contains indices, i.e., the accessor is only referenced by primitive.indices.
    componentType: ComponentType,

    /// Specifies whether integer data values should be normalized (true) to [0, 1] (for unsigned
    /// types) or [-1, 1] (for signed types), or converted directly (false) when they are accessed.
    /// This property is defined only for accessors that contain vertex attributes or animation
    /// output data.
    normalized: bool = false,

    /// The number of attributes referenced by this accessor, not to be confused with the number of
    /// bytes or number of components.
    count: usize,

    // TODO: maybe change this from enum to a string? Extensions may require it
    /// Specifies if the attribute is a scalar, vector, or matrix.
    @"type": enum {
        SCALAR,
        VEC2,
        VEC3,
        VEC4,
        MAT2,
        MAT3,
        MAT4,
    },

    /// Maximum value of each component in this attribute. Array elements must be treated as having
    /// the same data type as accessor's `componentType`. Both min and max arrays have the same
    /// length. The length is determined by the value of the type property; it can be 1, 2, 3, 4, 9,
    /// or 16.
    ///
    /// `normalized` property has no effect on array values: they always correspond to the actual
    /// values stored in the buffer. When accessor is sparse, this property must contain max values
    /// of accessor data with sparse substitution applied.
    max: ?[]f64 = null,

    /// Maximum value of each component in this attribute. Array elements must be treated as having
    /// the same data type as accessor's `componentType`. Both min and max arrays have the same
    /// length. The length is determined by the value of the type property; it can be 1, 2, 3, 4, 9,
    /// or 16.
    ///
    /// `normalized` property has no effect on array values: they always correspond to the actual
    /// values stored in the buffer. When accessor is sparse, this property must contain max values
    /// of accessor data with sparse substitution applied.
    min: ?[]f64 = null,

    /// Sparse storage of attributes that deviate from their initialization value.
    sparse: ?Sparse = null,

    /// The user-defined name of this object. This is not necessarily unique, e.g., an accessor and
    /// a buffer could have the same name, or two accessors could even have the same name.
    name: ?[]const u8 = null,

    /// Dictionary object with extension-specific objects.
    extensions: ?Map(json.Value) = null,

    /// Application-specific data
    extras: ?json.Value = null,

    pub const ComponentType = enum(u32) {
        Byte = BYTE,
        UnsignedByte = UNSIGNED_BYTE,
        Short = SHORT,
        UnsignedShort = UNSIGNED_SHORT,
        UnsignedInt = UNSIGNED_INT,
        Float = FLOAT,
    };

    pub const Sparse = struct {
        count: usize,
        indices: struct {
            bufferView: usize,
            byteOffset: usize,
            componentType: ComponentType,
        },
        values: struct {
            bufferView: usize,
            byteOffset: usize,
        },
    };
};

pub const Asset = struct {
    copyright: ?[]const u8 = null,
    generator: ?[]const u8 = null,
    version: []const u8,
    minVersion: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const Buffer = struct {
    uri: ?[]const u8 = null,
    byteLength: usize,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const ARRAY_BUFFER = 34962;
pub const ELEMENT_ARRAY_BUFFER = 34963;

pub const BufferView = struct {
    buffer: usize,
    byteOffset: usize = 0,
    byteLength: usize,
    stride: ?usize = null,
    target: ?enum(u32) {
        ArrayBuffer = ARRAY_BUFFER,
        ElementArrayBuffer = ELEMENT_ARRAY_BUFFER,
    } = null,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const Image = struct {
    uri: ?[]const u8 = null,
    mimeType: ?[]const u8 = null,
    bufferView: ?usize = null,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const Material = struct {
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
    pbrMetallicRoughness: PBR_MetallicRoughness = PBR_MetallicRoughness{},
    normalTexture: ?NormalTexture = null,
    occlusionTexture: ?OcclusionTexture = null,
    emissiveTexture: ?EmissiveTexture = null,
    emissiveFactor: [3]f64 = [_]f64{ 0, 0, 0 },
    alphaMode: enum {
        OPAQUE,
        MASK,
        BLEND,
    } = .OPAQUE,
    alphaCutoff: f64 = 0.5,
    doubleSided: bool = false,

    pub const PBR_MetallicRoughness = struct {
        baseColorFactor: [4]f64 = [4]f64{ 1, 1, 1, 1 },
        baseColorTexture: ?Map(json.Value) = null,
        metallicFactor: f64 = 1,
        roughnessFactor: f64 = 1,
        metallicRoughnessTexture: ?Map(json.Value) = null,
        extensions: ?Map(json.Value) = null,
        extras: ?json.Value = null,
    };

    pub const NormalTexture = struct {
        index: usize,
        texCoord: usize = 0,
        scale: f64 = 1,
        extensions: ?Map(json.Value) = null,
        extras: ?json.Value = null,
    };

    pub const OcclusionTexture = struct {
        index: usize,
        texCoord: usize = 0,
        strength: f64 = 1,
        extensions: ?Map(json.Value) = null,
        extras: ?json.Value = null,
    };

    pub const EmissiveTexture = struct {
        index: usize,
        texCoord: usize = 0,
        extensions: ?Map(json.Value) = null,
        extras: ?json.Value = null,
    };
};

const POINTS = 0;
const LINES = 1;
const LINE_LOOP = 2;
const LINE_STRIP = 3;
const TRIANGLES = 4;
const TRIANGLE_STRIP = 5;
const TRIANGLE_FAN = 6;

pub const Mesh = struct {
    primitives: []Primitive,
    weights: ?[]f64 = null,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,

    pub const Primitive = struct {
        attributes: Map(usize),
        indices: ?usize = null,
        material: ?usize = null,
        mode: enum {
            Points = POINTS,
            Lines = LINES,
            LineLoop = LINE_LOOP,
            LineStrip = LINE_STRIP,
            Triangles = TRIANGLES,
            TriangleStrip = TRIANGLE_STRIP,
            TriangleFan = TRIANGLE_FAN,
        } = .Triangles,
        targets: ?[]Map(usize) = null,
        extensions: ?Map(json.Value) = null,
        extras: ?json.Value = null,
    };
};

pub const Node = struct {
    camera: ?usize = null,
    children: []usize = &[_]usize{},
    skin: ?usize = null,
    matrix: ?[16]f64 = null,
    mesh: ?usize = null,
    rotation: ?[4]f64 = null,
    scale: ?[3]f64 = null,
    translation: ?[3]f64 = null,
    weights: ?[]f64 = null,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const NEAREST = 9728;
pub const LINEAR = 9729;
pub const NEAREST_MIPMAP_NEAREST = 9984;
pub const LINEAR_MIPMAP_NEAREST = 9985;
pub const NEAREST_MIPMAP_LINEAR = 9986;
pub const LINEAR_MIPMAP_LINEAR = 9987;
pub const CLAMP_TO_EDGE = 33071;
pub const MIRRORED_REPEAT = 33648;
pub const REPEAT = 10497;

pub const Sampler = struct {
    magFilter: ?enum(u32) {
        Nearest = NEAREST,
        Linear = LINEAR,
    } = null,
    minFilter: ?enum(u32) {
        Nearest = NEAREST,
        Linear = LINEAR,
        NearestMipmapNearest = NEAREST_MIPMAP_NEAREST,
        LinearMipmapNearest = LINEAR_MIPMAP_NEAREST,
        NearestMipmapLinear = NEAREST_MIPMAP_LINEAR,
        LinearMipmapLinear = LINEAR_MIPMAP_LINEAR,
    } = null,
    wrapS: WrappingMode = .Repeat,
    wrapT: WrappingMode = .Repeat,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,

    pub const WrappingMode = enum(u32) {
        ClampToEdge = CLAMP_TO_EDGE,
        MirroredRepeat = MIRRORED_REPEAT,
        Repeat = REPEAT,
    };
};

pub const Scene = struct {
    nodes: []usize = &[_]usize{},
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};

pub const Texture = struct {
    sampler: ?usize = null,
    source: ?usize = null,
    name: ?[]const u8 = null,
    extensions: ?Map(json.Value) = null,
    extras: ?json.Value = null,
};
