const clap = @import("clap");
const std = @import("std");
const langTable = @import("languages.zig");

const debug = std.debug;
const io = std.io;
const Allocator = std.mem.Allocator;

const Error = error{ LanguageNotSpecified, LanguageNameTooLong };

// trying writing this with no heap allocation and using a single buffer throughout
const languageNameMaxLength = 64;
const bufferSize = 4096;
var buffer: [bufferSize]u8 = undefined;

var fixedBuffer = std.heap.FixedBufferAllocator.init(buffer[0..]);
var ally = &fixedBuffer.allocator;

fn Options() type {
    return struct {
        language: [languageNameMaxLength]u8,
        ally: *Allocator,

        const Self = @This();

        fn programName() ![]const u8 {
            var allArgs = std.process.args();
            const pname = try allArgs.next(ally) orelse unreachable;
            return pname;
        }

        pub fn init() !?Self {
            defer fixedBuffer.reset();

            const params = comptime [_]clap.Param(clap.Help){
                try clap.parseParam("-h, --help             Display this help and exit.              "),
                try clap.parseParam("-l, --language <LANG>   One of (c csharp fsharp java)."),
                try clap.parseParam("-c, --color <ON/OFF/AUTO>  Not implemented."),
                try clap.parseParam("<INPUT_FILE>"),
            };

            var diag = clap.Diagnostic{};
            const program_name = try Self.programName();
            defer ally.free(program_name);

            var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag, .allocator = ally }) catch |err| {
                const errW = io.getStdErr().writer();
                diag.report(errW, err) catch {};

                try errW.print("{s} ", .{std.fs.path.basename(program_name)});

                try clap.usage(errW, &params);
                return err;
            };
            defer args.deinit();

            const lang = args.option("--language");
            const help = args.flag("--help");

            const errW = io.getStdErr().writer();

            // If lang paramete is supplied, return it, otherwise complain if not help
            if (lang) |l| {
                if (l.len > languageNameMaxLength) return Error.LanguageNameTooLong;
                var r = Self{
                    .language = undefined,
                    .ally = ally,
                };
                std.mem.copy(u8, &r.language, l);
                r.language[l.len] = 0;
                return r;
            } else if (!help) try errW.writeAll("The argument -l is required.\n");

            // We are either in --help or error mode here, in any case print usage
            try errW.writeAll("Usage: ");
            try errW.print("{s} ", .{std.fs.path.basename(program_name)});
            try clap.usage(errW, &params);
            try errW.writeAll("\n");
            try errW.writeAll(
                \\Transforms a commented file into a markdown document according to commenting patterns.
            );
            try errW.writeAll("\n");
            try clap.help(errW, &params);
            try langTable.printLanguages();
            if (!help) return Error.LanguageNotSpecified else return null;
        }
    };
}

pub fn main() !u8 {
    const errW = io.getStdErr().writer();

    var options = Options().init() catch |err| switch (err) {
        Error.LanguageNotSpecified, error.InvalidArgument, error.MissingValue => return 1,
        Error.LanguageNameTooLong => {
            try errW.print("Really? Are there language names bigger than {} chars? Not supported.", .{languageNameMaxLength});
            return 1;
        },
        error.OutOfMemory => {
            try errW.print("Really? You are using cmd line parameters bigger than {} chars? Not supported.", .{bufferSize});
            return 1;
        },
        else => return err,
    };
    if (options == null) return 0; // calling --help returns null

    // Cast a pointer to array to a null terminated slice and then gets a normal slice for it
    const lang: []u8 = std.mem.span(@ptrCast([*:0]u8, &options.?.language));
    const langLower = try std.ascii.allocLowerString(ally, lang);
    defer ally.free(langLower);

    const delimiters = langTable.languages.get(langLower);

    if (delimiters == null) {
        try errW.print("{s} is not a valid language.\n", .{lang});
        try langTable.printLanguages();
        try errW.writeAll("\n");
        return 1;
    }
    return 0;
}
