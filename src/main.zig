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
    var paren_count: i64 = 0;
    var line_to_tokenize = std.ArrayList(u8).init(gpa_allocator);
    defer line_to_tokenize.deinit();
    while (true) {
        if (paren_count == 0) try stdout.writeAll("zisp>");
        if (try stdin.reader().readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            if (line.len == 0) continue;
            if (std.mem.eql(u8, line, "quit") or std.mem.eql(u8, line, "exit")) {
                break;
            }
            try line_to_tokenize.appendSlice(line);
            paren_count += get_paren_count(line);
            if (paren_count == 0) {
                const final_line = try line_to_tokenize.toOwnedSlice();
                try tokenize(final_line, &tokens, arena_allocator);
                line_to_tokenize.clearRetainingCapacity();
                // Print all tokens(This is where the processing will happen)
                std.debug.print("Tokens:\n", .{});
                for (tokens.items) |token| {
                    std.debug.print("Type: {}, Value: {s}\n", .{ token.type, token.value });
                }
                //clearing the tokens
                tokens.clearRetainingCapacity();
            }
            if (paren_count != 0) try stdout.writeAll("...>");
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
            '*', '/', '+', '-' => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                if (i + 1 < input.len and is_char_symbol_token(input[i + 1])) {
                    while (i + 1 < input.len and is_char_symbol_token(input[i + 1])) {
                        try temp_string.append(input[i + 1]);
                        i += 1;
                    }
                }
                var final_string = try temp_string.toOwnedSlice();
                if ((final_string[0] == '+' or final_string[0] == '-') and is_following_a_number(final_string[1..])) {
                    final_string = if (final_string[0] == '+') final_string[1..] else final_string;
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
                while (i + 1 < input.len and is_char_symbol_token(input[i + 1])) {
                    try temp_string.append(input[i + 1]);
                    i += 1;
                }
                const final_string = try temp_string.toOwnedSlice();
                var is_token_number = true;
                for (final_string) |c| {
                    if (isNumber(c) == false) {
                        is_token_number = false;
                        break;
                    }
                }
                if (is_token_number == true) {
                    try tokens.append(Token{ .type = TokenType.Number, .value = final_string });
                } else {
                    try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
                }
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

fn is_following_a_number(s: []u8) bool {
    if (s.len == 0) return false;
    for (s) |char| {
        if (char < '0' or char > '9') return false;
    }
    return true;
}

fn is_char_symbol_token(s: u8) bool {
    switch (s) {
        '(', ')', '\n', '\t', ' ' => {
            return false;
        },
        else => {},
    }
    return true;
}

fn get_paren_count(s: []u8) i64 {
    var cnt: i64 = 0;
    for (s) |char| {
        switch (char) {
            '(' => cnt += 1,
            ')' => cnt -= 1,
            else => {},
        }
    }
    return cnt;
}
