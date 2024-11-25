const std = @import("std");

const TokenType = enum { leftParen, rightParen, Symbol, Number };

const Token = struct { type: TokenType, value: []const u8 };

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    //genral purpose allocator for common use
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    //arena allocator for tokenizing and parsing
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    //tokens array
    var tokens = std.ArrayList(Token).init(gpa_allocator);

    //io ops
    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.writeAll("zisp>");
        if (try stdin.reader().readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            if (line.len == 0) continue;
            if (std.mem.eql(u8, line, "quit") or std.mem.eql(u8, line, "exit")) {
                break;
            }

            try tokenize(line, &tokens, arena_allocator);
            // Print all tokens
            std.debug.print("Tokens:\n", .{});
            for (tokens.items) |token| {
                std.debug.print("Type: {}, Value: {s}\n", .{ token.type, token.value });
            }
        } else {
            break;
        }
    }
}

pub fn tokenize(input: []const u8, tokens: *std.ArrayList(Token), alloc: std.mem.Allocator) !void {
    var i: usize = 0;
    while (i < input.len) {
        const char = input[i];
        switch (char) {
            //covers left paranthesis
            '(' => try tokens.append(Token{ .type = TokenType.leftParen, .value = "(" }),
            //covers right paranthesis
            ')' => try tokens.append(Token{ .type = TokenType.rightParen, .value = ")" }),
            //covers all symbols and numbers prefixed with '+' and '-'
            '*', '/', '+' => {
                try tokens.append(Token{ .type = TokenType.Symbol, .value = input[i .. i + 1] });
            },
            '-' => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                var is_tokenType_number = false;
                if (i + 1 < input.len and isNumber(input[i + 1])) {
                    is_tokenType_number = true;
                    while (isNumber(input[i + 1])) {
                        try temp_string.append(input[i + 1]);
                        i += 1;
                    }
                }
                const final_string = try temp_string.toOwnedSlice();
                if (is_tokenType_number == true) {
                    try tokens.append(Token{ .type = TokenType.Number, .value = final_string });
                } else {
                    try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
                }
            },
            //All numbers covered
            '0'...'9' => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                while (i + 1 < input.len and input[i + 1] >= '0' and input[i + 1] <= '9') {
                    try temp_string.append(input[i + 1]);
                    i += 1;
                }
                const final_string = try temp_string.toOwnedSlice();
                try tokens.append(Token{ .type = TokenType.Number, .value = final_string });
            },
            //handling whitespaces, tabs, newlines
            '\t', '\n', ' ' => {
                //skip
            },
            else => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                while (i + 1 < input.len and is_char_symbol_token(input[i + 1]) == true) {
                    try temp_string.append(input[i + 1]);
                    i += 1;
                }
                const final_string = try temp_string.toOwnedSlice();
                try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
            },
        }
        i += 1;
    }
}

fn isNumber(c: u8) bool {
    if (c >= '0' and c <= '9') {
        return true;
    }
    return false;
}

fn is_char_symbol_token(s: u8) bool {
    switch (s) {
        '0'...'9', '(', ')', '+', '-', '*', '/', '\n', '\t', ' ' => {
            return false;
        },
        else => {},
    }
    return true;
}
