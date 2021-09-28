const std = @import("std");
const io = std.io;

pub const Delimiters = struct {
    line: []const u8,
    opening: []const u8,
    closing: []const u8,
};

pub const languages = std.ComptimeStringMap(Delimiters, .{
    .{ "c", .{ .line = "///", .opening = "/**", .closing = "**/" } },
    .{ "c++", .{ .line = "///", .opening = "/**", .closing = "**/" } },
    .{ "zig", .{ .line = "///", .opening = "", .closing = "" } },
});

pub fn printLanguages() !void {
    const errW = io.getStdErr().writer();
    try errW.writeAll("The valid languages are: ");
    for (languages.kvs) |kv| try errW.print("{s} ", .{kv.key});
}
