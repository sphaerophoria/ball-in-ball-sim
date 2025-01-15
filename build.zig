const std = @import("std");

pub fn build(b: *std.Build) !void {

    const query = try std.Target.Query.parse(.{
        .arch_os_abi = "wasm32-freestanding",
    });
    const target = b.resolveTargetQuery(query);
    const optimize = b.standardOptimizeOption(.{});

    const wasm = b.addExecutable(.{
        .name = "module",
        .root_source_file = b.path("src/wasm.zig"),
        .target = target,
        .optimize = optimize,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;

    b.installArtifact(wasm);

}
