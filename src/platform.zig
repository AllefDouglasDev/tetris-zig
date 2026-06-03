const std = @import("std");
const builtin = @import("builtin");

const backend = Backend.default();
const backend_name = backend.string();
const platform = backend.Api();

pub const MacosPlatform = PlatformImpl(.macos, @import("macos.zig"));
pub const WebPlatform = PlatformImpl(.web, @import("web.zig"));
pub const LinuxPlatform = PlatformImpl(.linux, @import("linux.zig"));
pub const WindowsPlatform = PlatformImpl(.windows, @import("windows.zig"));

pub const PlaceholderBackend = struct {};

pub const Backend = enum {
    linux,
    web,
    macos,
    windows,

    pub fn default() Backend  {
        return @as(?Backend, switch (builtin.os.tag) {
            .linux => .io_uring,
            .macos => .macos,
            else => switch (builtin.target.cpu.arch) {
                .wasm32, .wasm64 => .web,
                else => null,
            },
        }) orelse {
            @compileLog(builtin.os);
            @compileError("no deafult backend for this target");
        };
    }

    pub fn Api(comptime self: Backend) type {
        return switch (self) {
            .linux => LinuxPlatform,
            .web => WebPlatform,
            .macos => MacosPlatform,
            .windows => WindowsPlatform,
        };
    }

    pub fn string(comptime self: Backend) []const u8 {
        return switch (self) {
            .linux => "linux",
            .macos => "macos",
            .windows => "windows",
            .web => "web",
        };
    }
};

pub fn PlatformImpl(comptime be: Backend, comptime T: type) type {
    return struct {
        const Self = @This();
        pub const backend = be;
        pub const name = be.string();
        pub const Window = T.Window;
        pub const Logger = T.Logger;
    };
}
