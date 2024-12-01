const std = @import("std");

//Defining the errors
const ASTErrors = error{ NoParentNode, NoNodeInStack, NoPoppedNode, NoParentTokenFormed };

//Tokenizer pre-requisites
const TokenType = enum { leftParen, rightParen, Symbol, Number };
const Token = struct { type: TokenType, value: []const u8 };

//Parser pre-requisites
const NodeType = enum { number, symbol, ListNode };
//Why did i go with a struct instead of a tagged union, according to claude,
//  -more helpful in processing nodes in evaluator
//  -can add more info such as source location,info and debug info in future
const Node = struct { type: NodeType, value: union { number: i64, symbol: []const u8, list: std.ArrayList(Node) } };
//Again, might add more features to this Parent_AST that is why encapsulating it inside a struct
const Parent_AST = struct { expressions: std.ArrayList(Node) };

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
    defer tokens.deinit();

    //Central Node Storage for AST
    var AST = Parent_AST{ .expressions = std.ArrayList(Node).init(gpa_allocator) };
    defer AST.expressions.deinit();

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

                //Building AST
                try create_and_allocate_to_AST(&tokens, &AST.expressions, &arena_allocator);

                // <---------------------Uncomment this to print and see all the token that are being generated--------------->
                // print_tokens(&tokens);
                // <---------------------------------------------------------------------------------------------------------->

                // <---------------------Uncomment this to print and see AST structure that is generated---------------------->
                // print_AST(&AST.expressions);
                // <---------------------------------------------------------------------------------------------------------->

                //clearing the tokens
                tokens.clearRetainingCapacity();
            }
            if (paren_count != 0) try stdout.writeAll("...>");
        } else {
            break;
        }
    }
}
// <------------------------------------------------MAIN HELPER FUNCTIONS---------------------------------------------->
fn isNumber(c: u8) bool {
    if (c >= '0' and c <= '9') {
        return true;
    }
    return false;
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

fn print_tokens(tokens: *std.ArrayList(Token)) void {
    for (tokens.items) |token| {
        std.debug.print("Type: {}, Value: {s}\n", .{ token.type, token.value });
    }
}

fn print_AST(ast: *const std.ArrayList(Node)) void {
    for (ast.items) |node| {
        print_node(node, 0);
    }
}

fn print_node(node: Node, indent: usize) void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        std.debug.print(" ", .{});
    }

    switch (node.type) {
        .number => std.debug.print("Number: {}\n", .{node.value.number}),
        .symbol => std.debug.print("Symbol: {s}\n", .{node.value.symbol}),
        .ListNode => {
            std.debug.print("List:\n", .{});
            for (node.value.list.items) |child| {
                print_node(child, indent + 2);
            }
        },
    }
}
// <------------------------------------------------------------------------------------------------------------------->

//TOKENIZER
fn tokenize(input: []const u8, tokens: *std.ArrayList(Token), alloc: std.mem.Allocator) !void {
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
//<-------------------------------------------TOKENIZER HELPER FUNCTIONS------------------------------------------------>
fn is_char_symbol_token(s: u8) bool {
    switch (s) {
        '(', ')', '\n', '\t', ' ' => {
            return false;
        },
        else => {},
    }
    return true;
}

fn is_following_a_number(s: []u8) bool {
    if (s.len == 0) return false;
    for (s) |char| {
        if (char < '0' or char > '9') return false;
    }
    return true;
}
//<---------------------------------------------------------------------------------------------------------------------

//AST

//Creating a stack struct for storing recursive levels of nodes
const Node_stack = struct {
    nodes: std.ArrayList(Node),
    pub fn init(alloc: std.mem.Allocator) Node_stack {
        return Node_stack{ .nodes = std.ArrayList(Node).init(alloc) };
    }
    pub fn len(self: *Node_stack) usize {
        return self.nodes.items.len;
    }
    pub fn peek(self: *Node_stack) ?*Node {
        const len_nodes = self.nodes.items.len;
        if (len_nodes == 0) return null;
        return &self.nodes.items[len_nodes - 1];
    }
    pub fn pop(self: *Node_stack) ?Node {
        const len_nodes = self.nodes.items.len;
        if (len_nodes == 0) return null;
        return self.nodes.pop();
    }
    pub fn push(self: *Node_stack, n: *Node) !void {
        // std.debug.print("Pushing a node of type {any} with value {any}\n", .{ n.type, n.*.value });
        try self.nodes.append(n.*);
    }
    pub fn deinit(self: *Node_stack) void {
        self.nodes.deinit();
    }
};
fn create_and_allocate_to_AST(tokens: *const std.ArrayList(Token), AST: *std.ArrayList(Node), arena_alloc: *const std.mem.Allocator) !void {
    //we keep iterating each token, we need to keep track of the parent node,
    var node_stack = Node_stack.init(arena_alloc.*);

    defer node_stack.deinit();
    for (tokens.items) |token| {
        const parent_node = node_stack.peek();
        // std.debug.print("The type of the peeked parent_node is {any}\n", .{if (parent_node) |n| n.*.type else null});
        const res = try categorize_and_allocate(&token, parent_node, arena_alloc.*);
        //res might be void or it might return a Node, in the case that there is a node, we have to move it to the stack
        if (res) |child_node| {
            // std.debug.print("The returned node is of the type {any}\n", .{child_node.*.type});
            try node_stack.push(child_node);
        }
        // std.debug.print("Before we move ahead to ) checking, the tokenType is {any}\n", .{token.type});
        //if the token is ) then we have to conclude and move one stack up and restore the parent node
        if (token.type == TokenType.rightParen and node_stack.len() > 1) {
            //If the size >1 then we are sure that it is a child and a parent exists
            // std.debug.print("This is a proof that we entered the ) condition with the type {any}", .{token.type});
            const popped_node = node_stack.pop().?;
            if (node_stack.peek()) |node| {
                try node.*.value.list.append(popped_node);
            }
        }
    }

    if (node_stack.len() > 0) {
        try AST.append(node_stack.pop().?);
    } else {
        return ASTErrors.NoParentTokenFormed;
    }
}

//AST HELPER FUNCTIONS
fn categorize_and_allocate(token: *const Token, parent_node: ?*Node, arena_alloc: std.mem.Allocator) !?*Node {
    // std.debug.print("Got the node {s}", .{token.value});
    // const s = if (parent_node) |n| n.*.type else null;
    // std.debug.print("The incoming parent_node is of the type {any}\n", .{s});
    //if left paranthesis, these new Node of type Node[] is created and we assign left to it and return
    switch (token.type) {
        TokenType.leftParen => {
            const new_node = try arena_alloc.create(Node);
            new_node.* = Node{ .type = NodeType.ListNode, .value = .{ .list = std.ArrayList(Node).init(arena_alloc) } };
            const temp = Node{ .type = NodeType.symbol, .value = .{ .symbol = token.value } };
            try new_node.*.value.list.append(temp);
            return new_node;
        },
        TokenType.Symbol, TokenType.rightParen => {
            const temp = Node{ .type = NodeType.symbol, .value = .{ .symbol = token.value } };
            if (parent_node) |node| {
                try node.*.value.list.append(temp);
            } else {
                return ASTErrors.NoParentNode;
            }
            // try (parent_node.* orelse return ASTErrors.NoParentNode).value.list.append(temp);
        },
        TokenType.Number => {
            // std.debug.print("The value being transformed is {any} and the type of parent_node is {any}\n", .{ token.value, parent_node.?.type });
            const val = try std.fmt.parseInt(i64, token.value, 10);
            const temp = Node{ .type = NodeType.number, .value = .{ .number = val } };
            if (parent_node) |node| {
                try node.*.value.list.append(temp);
            } else {
                return ASTErrors.NoParentNode;
            }
        },
    }
    return null;
}
