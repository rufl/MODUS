const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var child_args = std.ArrayListUnmanaged([]const u8).empty;
    defer child_args.deinit(allocator);

    const executable = args[0];
    const separator = std.mem.lastIndexOfAny(u8, executable, "/\\");
    const directory = if (separator) |index| executable[0 .. index + 1] else "";
    const real_executable = try std.fmt.allocPrint(allocator, "{s}modus-real.exe", .{directory});
    defer allocator.free(real_executable);
    try child_args.append(allocator, real_executable);

    var package_smoke = false;
    var headless = false;
    for (args[1..]) |argument| {
        if (std.mem.eql(u8, argument, "--package-smoke")) package_smoke = true;
        if (std.mem.eql(u8, argument, "--headless")) headless = true;
    }
    if (package_smoke and !headless) try child_args.append(allocator, "--headless");
    try child_args.appendSlice(allocator, args[1..]);

    var child = try std.process.spawn(init.io, .{
        .argv = child_args.items,
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });
    const term = try child.wait(init.io);
    switch (term) {
        .exited => |code| std.process.exit(code),
        else => return error.ModusLauncherTerminated,
    }
}
