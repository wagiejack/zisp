const std = @import("std");

//Defining the errors
const ASTErrors = error{ NoParentNode, NoNodeInStack, NoPoppedNode, NoParentTokenFormed };
const EvalError = error{ TypeMismatch, DivisionByZero, InvalidArguments, NoValueExistsForKeyInEnvironment, InvalidSymbolAtBeginningOfExpression, TestingError, ThisNeedsToBeInsideParenthesis };

//Tokenizer pre-requisites
const TokenType = enum { leftParen, rightParen, Symbol, Number };
const Token = struct { type: TokenType, value: []const u8 };

//Parser pre-requisites
const specialFormType = enum {
    Define, // Variables/functions
    Lambda, // Function creation
    If, // Basic conditionals
    Quote, // Raw data
    Begin, // Multiple expressions
};
const NodeType = enum { number, symbol, ListNode, specialFormType };
const Node = struct { type: NodeType, value: union { number: i64, symbol: []const u8, list: std.ArrayList(Node), specialForm: specialFormType } };
const Parent_AST = struct { expressions: std.ArrayList(Node) };

//Evaluator pre-requisites

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

                //Main Evaluation
                for (AST.expressions.items) |ast| {
                    const result = try eval(&ast, null, &gpa_allocator);
                    std.debug.print("Result : {any}\n", .{result.number});
                }

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
    // Clear any previous outputs
    for (ast.items) |node| {
        print_node(node, 0);
    }
}

fn print_node(node: Node, indent: usize) void {
    // Print indentation for visual hierarchy
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        std.debug.print(" ", .{});
    }

    // Handle each possible node type
    switch (node.type) {
        .number => std.debug.print("Number: {}\n", .{node.value.number}),
        .symbol => std.debug.print("Symbol: {s}\n", .{node.value.symbol}),
        .ListNode => {
            std.debug.print("List:\n", .{});
            for (node.value.list.items) |child| {
                print_node(child, indent + 2);
            }
        },
        .specialFormType => std.debug.print("Special Form: {s}\n", .{switch (node.value.specialForm) {
            .Define => "define",
            .Lambda => "lambda",
            .If => "if",
            .Quote => "quote",
            .Begin => "begin",
        }}),
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
            '>', '<' => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                while (i + 1 < input.len and isNumber(input[i + 1]) == false and is_character(input[i + 1]) == false and is_char_not_whitespace(input[i + 1]) == true) {
                    if (input[i + 1] == '=') {
                        try temp_string.append(input[i + 1]);
                        i += 1;
                    } else {
                        break;
                    }
                }
                const final_string = try temp_string.toOwnedSlice();
                try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
            },
            //covers all symbols and numbers prefixed with '+' and '-'
            '*', '/', '+', '-', '=' => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                while (i + 1 < input.len and is_char_not_whitespace_or_symbol_token(input[i + 1])) {
                    try temp_string.append(input[i + 1]);
                    i += 1;
                }
                var final_string = try temp_string.toOwnedSlice();
                if ((final_string[0] == '+' or final_string[0] == '-') and is_following_a_number(final_string[1..])) {
                    final_string = if (final_string[0] == '+') final_string[1..] else final_string;
                    try tokens.append(Token{ .type = TokenType.Number, .value = final_string });
                } else {
                    const str = try alloc.dupe(u8, &[_]u8{final_string[0]});
                    try tokens.append(Token{ .type = TokenType.Symbol, .value = str });
                    if (final_string.len > 1) {
                        try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string[1..] });
                    }
                }
            },
            //All numbers covered
            '0'...'9' => {
                var temp_string = std.ArrayList(u8).init(alloc);
                defer temp_string.deinit();
                try temp_string.append(char);
                while (i + 1 < input.len and is_char_not_whitespace(input[i + 1])) {
                    switch (input[i + 1]) {
                        '+', '-', '*', '/', '<', '>', '=' => {
                            if (temp_string.items.len > 0) {
                                const final_string = try temp_string.toOwnedSlice();
                                try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
                            }
                            const str = try alloc.dupe(u8, &[_]u8{input[i + 1]});
                            try tokens.append(Token{ .type = TokenType.Symbol, .value = str });
                            temp_string.clearRetainingCapacity();
                        },
                        else => {
                            try temp_string.append(input[i + 1]);
                        },
                    }
                    i += 1;
                }
                if (temp_string.items.len > 0) {
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
                while (i + 1 < input.len and is_char_not_whitespace(input[i + 1])) {
                    switch (input[i + 1]) {
                        '+', '-', '*', '/', '<', '>', '=' => {
                            if (temp_string.items.len > 0) {
                                const final_string = try temp_string.toOwnedSlice();
                                try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
                            }
                            const str = try alloc.dupe(u8, &[_]u8{input[i + 1]});
                            try tokens.append(Token{ .type = TokenType.Symbol, .value = str });
                            temp_string.clearRetainingCapacity();
                        },
                        else => {
                            try temp_string.append(input[i + 1]);
                        },
                    }
                    i += 1;
                }
                if (temp_string.items.len > 0) {
                    const final_string = try temp_string.toOwnedSlice();
                    try tokens.append(Token{ .type = TokenType.Symbol, .value = final_string });
                }
            },
        }
        i += 1;
    }
}
//<-------------------------------------------TOKENIZER HELPER FUNCTIONS------------------------------------------------>
fn is_char_not_whitespace_or_symbol_token(s: u8) bool {
    switch (s) {
        '(', ')', '\n', '\t', ' ', '+', '-', '<', '>', '=', '*', '/' => {
            return false;
        },
        else => {},
    }
    return true;
}

fn is_char_not_whitespace(s: u8) bool {
    switch (s) {
        '(', ')', '\n', '\t', ' ' => {
            return false;
        },
        else => {},
    }
    return true;
}

fn is_character(s: u8) bool {
    return (s >= 'a' and s <= 'z') or (s >= 'A' and s <= 'Z');
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
        try self.nodes.append(n.*);
    }
    pub fn deinit(self: *Node_stack) void {
        self.nodes.deinit();
    }
};
fn create_and_allocate_to_AST(tokens: *const std.ArrayList(Token), AST: *std.ArrayList(Node), arena_alloc: *const std.mem.Allocator) !void {
    var node_stack = Node_stack.init(arena_alloc.*);

    defer node_stack.deinit();
    for (tokens.items) |token| {
        const parent_node = node_stack.peek();
        const res = try categorize_and_allocate(&token, parent_node, arena_alloc.*);
        if (res) |child_node| {
            try node_stack.push(child_node);
        }
        if (token.type == TokenType.rightParen and node_stack.len() > 1) {
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
    switch (token.type) {
        TokenType.leftParen => {
            const new_node = try arena_alloc.create(Node);
            new_node.* = Node{ .type = NodeType.ListNode, .value = .{ .list = std.ArrayList(Node).init(arena_alloc) } };
            const temp = Node{ .type = NodeType.symbol, .value = .{ .symbol = token.value } };
            try new_node.*.value.list.append(temp);
            return new_node;
        },
        TokenType.Symbol, TokenType.rightParen => {
            var temp: Node = undefined;
            if (std.mem.eql(u8, token.value, "define")) {
                temp = Node{ .type = NodeType.specialFormType, .value = .{ .specialForm = specialFormType.Define } };
            } else if (std.mem.eql(u8, token.value, "lambda")) {
                temp = Node{ .type = NodeType.specialFormType, .value = .{ .specialForm = specialFormType.Lambda } };
            } else if (std.mem.eql(u8, token.value, "if")) {
                temp = Node{ .type = NodeType.specialFormType, .value = .{ .specialForm = specialFormType.If } };
            } else if (std.mem.eql(u8, token.value, "quote")) {
                temp = Node{ .type = NodeType.specialFormType, .value = .{ .specialForm = specialFormType.Quote } };
            } else if (std.mem.eql(u8, token.value, "begin")) {
                temp = Node{ .type = NodeType.specialFormType, .value = .{ .specialForm = specialFormType.Begin } };
            } else {
                temp = Node{ .type = NodeType.symbol, .value = .{ .symbol = token.value } };
            }
            if (parent_node) |node| {
                try node.*.value.list.append(temp);
            } else {
                return ASTErrors.NoParentNode;
            }
        },
        TokenType.Number => {
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

// Evaluator

//Bring this to evaluator pre-requisites later
const Value = union(enum) {
    number: i64,
    function: *const fn ([]const Value) EvalError!Value,
};
const Environment = struct {
    values: std.StringHashMap(Value),
    parent: ?*Environment,

    pub fn init(alloc: *const std.mem.Allocator, parent: ?*Environment) !Environment {
        var env = Environment{
            .values = std.StringHashMap(Value).init(alloc.*),
            .parent = parent,
        };

        if (parent) |p| {
            var iter = p.values.iterator();
            while (iter.next()) |entry| {
                try env.values.put(entry.key_ptr.*, entry.value_ptr.*);
            }
        }
        return env;
    }
};

fn eval(node: *const Node, parent_env: ?*Environment, alloc: *const std.mem.Allocator) anyerror!Value {
    switch (node.type) {
        NodeType.ListNode => {
            const len = node.value.list.items.len;
            const expression = node.value.list.items[1 .. len - 1];

            const operator = expression[0];
            const args = expression[1..];
            var new_env = try Environment.init(alloc, parent_env);
            switch (operator.type) {
                NodeType.ListNode, NodeType.number => {
                    return EvalError.InvalidSymbolAtBeginningOfExpression;
                },
                NodeType.specialFormType => {},
                NodeType.symbol => {
                    const op = operator.value.symbol;
                    switch (op[0]) {
                        '+' => {
                            return Value{ .number = try add(&args, &new_env, alloc) };
                        },
                        '-' => {
                            return Value{ .number = try sub(&args, &new_env, alloc) };
                        },
                        '*' => {
                            return Value{ .number = try multiply(&args, &new_env, alloc) };
                        },
                        '/' => {
                            return Value{ .number = try divide(&args, &new_env, alloc) };
                        },
                        else => {
                            return EvalError.InvalidSymbolAtBeginningOfExpression;
                        },
                    }
                },
            }
        },
        NodeType.number => {
            return Value{ .number = node.value.number };
        },
        // NodeType.symbol => {
        //     return Value{};
        // },
        // NodeType.specialFormType => {
        //     return Value{};
        // },
        else => {
            return EvalError.TestingError;
        },
    }
    return EvalError.DivisionByZero;
}

//const NodeType = enum { number, symbol, ListNode, specialFormType };
// const Node = struct { type: NodeType, value: union { number: i64, symbol: []const u8, list: std.ArrayList(Node), specialForm: specialFormType } };
fn add(args: *const []Node, current_env: ?*Environment, alloc: *const std.mem.Allocator) !i64 {
    var result: i64 = 0;
    for (args.*) |n| {
        switch (n.type) {
            NodeType.number => {
                result += n.value.number;
            },
            NodeType.ListNode => {
                const temp_res = try eval(&n, current_env, alloc);
                result += temp_res.number;
            },
            NodeType.symbol => {
                //Look at it in the map and parent maps
            },
            NodeType.specialFormType => {
                return EvalError.ThisNeedsToBeInsideParenthesis;
            },
        }
    }
    return result;
}

fn sub(args: *const []Node, current_env: ?*Environment, alloc: *const std.mem.Allocator) !i64 {
    var result: i64 = 0;
    for (args.*) |n| {
        switch (n.type) {
            NodeType.number => {
                result -= n.value.number;
            },
            NodeType.ListNode => {
                const temp_res = try eval(&n, current_env, alloc);
                result -= temp_res.number;
            },
            NodeType.symbol => {
                //Look at it and map the parent maps
            },
            NodeType.specialFormType => {
                return EvalError.ThisNeedsToBeInsideParenthesis;
            },
        }
    }
    return result;
}

fn multiply(args: *const []Node, current_env: ?*Environment, alloc: *const std.mem.Allocator) !i64 {
    var result: i64 = undefined;
    var is_result_undefined = true;
    for (args.*) |n| {
        switch (n.type) {
            NodeType.number => {
                if (is_result_undefined == true) {
                    is_result_undefined = false;
                    result = n.value.number;
                } else {
                    result = result * n.value.number;
                }
            },
            NodeType.ListNode => {
                const temp_res = try eval(&n, current_env, alloc);
                if (is_result_undefined == true) {
                    is_result_undefined = false;
                    result = temp_res.number;
                } else {
                    result = result * temp_res.number;
                }
            },
            NodeType.symbol => {
                //Look at it and map the parent maps
            },
            NodeType.specialFormType => {
                return EvalError.ThisNeedsToBeInsideParenthesis;
            },
        }
    }
    return result;
}

fn divide(args: *const []Node, current_env: ?*Environment, alloc: *const std.mem.Allocator) !i64 {
    var result: i64 = undefined;
    var is_result_undefined = true;
    for (args.*) |n| {
        switch (n.type) {
            NodeType.number => {
                if (is_result_undefined == true) {
                    is_result_undefined = false;
                    result = n.value.number;
                } else if (n.value.number != 0) {
                    result = @divTrunc(result, n.value.number);
                } else {
                    return EvalError.DivisionByZero;
                }
            },
            NodeType.ListNode => {
                const temp_res = try eval(&n, current_env, alloc);
                if (is_result_undefined == true) {
                    is_result_undefined = false;
                    result = temp_res.number;
                } else if (temp_res.number != 0) {
                    result = @divTrunc(result, temp_res.number);
                } else {
                    return EvalError.DivisionByZero;
                }
            },
            NodeType.symbol => {
                //Look at it and map the parent maps
            },
            NodeType.specialFormType => {
                return EvalError.ThisNeedsToBeInsideParenthesis;
            },
        }
    }
    return result;
}
