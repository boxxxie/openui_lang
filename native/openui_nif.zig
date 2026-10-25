const std = @import("std");

pub const ErlNifEnv = opaque {};
pub const ERL_NIF_TERM = usize;

extern fn nif_inspect_binary(env: ?*ErlNifEnv, term: ERL_NIF_TERM, data_out: *[*]const u8, size_out: *usize) c_int;
extern fn nif_get_int(env: ?*ErlNifEnv, term: ERL_NIF_TERM, val_out: *c_int) c_int;
extern fn nif_make_binary_slice(env: ?*ErlNifEnv, src: ?[*]const u8, len: usize) ERL_NIF_TERM;
extern fn nif_make_sub_binary(env: ?*ErlNifEnv, bin_term: ERL_NIF_TERM, pos: usize, size: usize) ERL_NIF_TERM;
extern fn nif_make_atom_len(env: ?*ErlNifEnv, name: [*]const u8, len: usize) ERL_NIF_TERM;
extern fn nif_make_int64(env: ?*ErlNifEnv, val: i64) ERL_NIF_TERM;
extern fn nif_make_double(env: ?*ErlNifEnv, val: f64) ERL_NIF_TERM;
extern fn nif_make_tuple2(env: ?*ErlNifEnv, e1: ERL_NIF_TERM, e2: ERL_NIF_TERM) ERL_NIF_TERM;
extern fn nif_make_tuple3(env: ?*ErlNifEnv, e1: ERL_NIF_TERM, e2: ERL_NIF_TERM, e3: ERL_NIF_TERM) ERL_NIF_TERM;
extern fn nif_make_tuple4(env: ?*ErlNifEnv, e1: ERL_NIF_TERM, e2: ERL_NIF_TERM, e3: ERL_NIF_TERM, e4: ERL_NIF_TERM) ERL_NIF_TERM;
extern fn nif_make_tuple5(env: ?*ErlNifEnv, e1: ERL_NIF_TERM, e2: ERL_NIF_TERM, e3: ERL_NIF_TERM, e4: ERL_NIF_TERM, e5: ERL_NIF_TERM) ERL_NIF_TERM;
extern fn nif_make_list_from_array(env: ?*ErlNifEnv, arr: ?[*]const ERL_NIF_TERM, cnt: c_uint) ERL_NIF_TERM;
extern fn nif_make_map_from_arrays(env: ?*ErlNifEnv, keys: ?[*]ERL_NIF_TERM, vals: ?[*]ERL_NIF_TERM, cnt: usize, map_out: *ERL_NIF_TERM) c_int;
extern fn nif_make_badarg(env: ?*ErlNifEnv) ERL_NIF_TERM;
extern fn nif_alloc(size: usize) ?[*]u8;
extern fn nif_free(ptr: ?[*]u8) void;
extern fn nif_parse_double(ptr: [*]const u8, len: usize) f64;

// Pre-cached BEAM atoms (populated in zig_nif_load)
const Atoms = struct {
    newline: ERL_NIF_TERM = 0,
    eof: ERL_NIF_TERM = 0,
    lparen: ERL_NIF_TERM = 0,
    rparen: ERL_NIF_TERM = 0,
    lbrack: ERL_NIF_TERM = 0,
    rbrack: ERL_NIF_TERM = 0,
    lbrace: ERL_NIF_TERM = 0,
    rbrace: ERL_NIF_TERM = 0,
    comma: ERL_NIF_TERM = 0,
    colon: ERL_NIF_TERM = 0,
    dot: ERL_NIF_TERM = 0,
    question: ERL_NIF_TERM = 0,
    plus: ERL_NIF_TERM = 0,
    minus: ERL_NIF_TERM = 0,
    star: ERL_NIF_TERM = 0,
    slash: ERL_NIF_TERM = 0,
    percent: ERL_NIF_TERM = 0,
    eq_eq: ERL_NIF_TERM = 0,
    equals: ERL_NIF_TERM = 0,
    not_eq: ERL_NIF_TERM = 0,
    not_tok: ERL_NIF_TERM = 0,
    greater_eq: ERL_NIF_TERM = 0,
    greater: ERL_NIF_TERM = 0,
    less_eq: ERL_NIF_TERM = 0,
    less: ERL_NIF_TERM = 0,
    and_tok: ERL_NIF_TERM = 0,
    or_tok: ERL_NIF_TERM = 0,
    true_atom: ERL_NIF_TERM = 0,
    false_atom: ERL_NIF_TERM = 0,
    null_atom: ERL_NIF_TERM = 0,
    nil_atom: ERL_NIF_TERM = 0,
    str: ERL_NIF_TERM = 0,
    num: ERL_NIF_TERM = 0,
    ident: ERL_NIF_TERM = 0,
    type_tok: ERL_NIF_TERM = 0,
    state_var: ERL_NIF_TERM = 0,
    builtin_call: ERL_NIF_TERM = 0,

    // AST keys & node kinds
    k: ERL_NIF_TERM = 0,
    v: ERL_NIF_TERM = 0,
    n: ERL_NIF_TERM = 0,
    comp: ERL_NIF_TERM = 0,
    name: ERL_NIF_TERM = 0,
    args: ERL_NIF_TERM = 0,
    fn_key: ERL_NIF_TERM = 0,
    ref: ERL_NIF_TERM = 0,
    state_ref: ERL_NIF_TERM = 0,
    bool_kind: ERL_NIF_TERM = 0,
    arr: ERL_NIF_TERM = 0,
    els: ERL_NIF_TERM = 0,
    obj: ERL_NIF_TERM = 0,
    entries: ERL_NIF_TERM = 0,
    bin_op: ERL_NIF_TERM = 0,
    op: ERL_NIF_TERM = 0,
    left: ERL_NIF_TERM = 0,
    right: ERL_NIF_TERM = 0,
    unary_op: ERL_NIF_TERM = 0,
    operand: ERL_NIF_TERM = 0,
    ternary: ERL_NIF_TERM = 0,
    cond_key: ERL_NIF_TERM = 0,
    then_key: ERL_NIF_TERM = 0,
    else_key: ERL_NIF_TERM = 0,
    member: ERL_NIF_TERM = 0,
    field: ERL_NIF_TERM = 0,
    index: ERL_NIF_TERM = 0,
    assign: ERL_NIF_TERM = 0,
    target: ERL_NIF_TERM = 0,
    value: ERL_NIF_TERM = 0,
    ph: ERL_NIF_TERM = 0,

    // Statement classification keys & kinds
    kind: ERL_NIF_TERM = 0,
    id: ERL_NIF_TERM = 0,
    expr: ERL_NIF_TERM = 0,
    init: ERL_NIF_TERM = 0,
    call: ERL_NIF_TERM = 0,
    callee: ERL_NIF_TERM = 0,
    state_refs: ERL_NIF_TERM = 0,
    refs: ERL_NIF_TERM = 0,
    deps: ERL_NIF_TERM = 0,
    query: ERL_NIF_TERM = 0,
    mutation: ERL_NIF_TERM = 0,
    state: ERL_NIF_TERM = 0,

    // Auto-close keys & TUI tuple tags
    text: ERL_NIF_TERM = 0,
    was_incomplete: ERL_NIF_TERM = 0,
    var_atom: ERL_NIF_TERM = 0,
    unresolved: ERL_NIF_TERM = 0,
    prose: ERL_NIF_TERM = 0,
    code: ERL_NIF_TERM = 0,
    empty: ERL_NIF_TERM = 0,
};

var A: Atoms = .{};

fn makeAtom(env: ?*ErlNifEnv, comptime s: []const u8) ERL_NIF_TERM {
    return nif_make_atom_len(env, s.ptr, s.len);
}

fn makeBin(env: ?*ErlNifEnv, s: []const u8) ERL_NIF_TERM {
    if (s.len == 0) {
        const empty = "";
        return nif_make_binary_slice(env, empty.ptr, 0);
    }
    return nif_make_binary_slice(env, s.ptr, s.len);
}

fn makeMap(env: ?*ErlNifEnv, keys: []ERL_NIF_TERM, vals: []ERL_NIF_TERM) ERL_NIF_TERM {
    var out: ERL_NIF_TERM = 0;
    _ = nif_make_map_from_arrays(
        env,
        if (keys.len > 0) keys.ptr else null,
        if (vals.len > 0) vals.ptr else null,
        keys.len,
        &out,
    );
    return out;
}

fn makeList(env: ?*ErlNifEnv, items: []const ERL_NIF_TERM) ERL_NIF_TERM {
    return nif_make_list_from_array(
        env,
        if (items.len > 0) items.ptr else null,
        @intCast(items.len),
    );
}

export fn zig_nif_load(env: ?*ErlNifEnv, _priv_data: ?*?*anyopaque, _load_info: ERL_NIF_TERM) c_int {
    _ = _priv_data;
    _ = _load_info;

    A.newline = makeAtom(env, "newline");
    A.eof = makeAtom(env, "eof");
    A.lparen = makeAtom(env, "lparen");
    A.rparen = makeAtom(env, "rparen");
    A.lbrack = makeAtom(env, "lbrack");
    A.rbrack = makeAtom(env, "rbrack");
    A.lbrace = makeAtom(env, "lbrace");
    A.rbrace = makeAtom(env, "rbrace");
    A.comma = makeAtom(env, "comma");
    A.colon = makeAtom(env, "colon");
    A.dot = makeAtom(env, "dot");
    A.question = makeAtom(env, "question");
    A.plus = makeAtom(env, "plus");
    A.minus = makeAtom(env, "minus");
    A.star = makeAtom(env, "star");
    A.slash = makeAtom(env, "slash");
    A.percent = makeAtom(env, "percent");
    A.eq_eq = makeAtom(env, "eq_eq");
    A.equals = makeAtom(env, "equals");
    A.not_eq = makeAtom(env, "not_eq");
    A.not_tok = makeAtom(env, "not");
    A.greater_eq = makeAtom(env, "greater_eq");
    A.greater = makeAtom(env, "greater");
    A.less_eq = makeAtom(env, "less_eq");
    A.less = makeAtom(env, "less");
    A.and_tok = makeAtom(env, "and");
    A.or_tok = makeAtom(env, "or");
    A.true_atom = makeAtom(env, "true");
    A.false_atom = makeAtom(env, "false");
    A.null_atom = makeAtom(env, "null");
    A.nil_atom = makeAtom(env, "nil");
    A.str = makeAtom(env, "str");
    A.num = makeAtom(env, "num");
    A.ident = makeAtom(env, "ident");
    A.type_tok = makeAtom(env, "type");
    A.state_var = makeAtom(env, "state_var");
    A.builtin_call = makeAtom(env, "builtin_call");

    A.k = makeAtom(env, "k");
    A.v = makeAtom(env, "v");
    A.n = makeAtom(env, "n");
    A.comp = makeAtom(env, "comp");
    A.name = makeAtom(env, "name");
    A.args = makeAtom(env, "args");
    A.fn_key = makeAtom(env, "fn");
    A.ref = makeAtom(env, "ref");
    A.state_ref = makeAtom(env, "state_ref");
    A.bool_kind = makeAtom(env, "bool");
    A.arr = makeAtom(env, "arr");
    A.els = makeAtom(env, "els");
    A.obj = makeAtom(env, "obj");
    A.entries = makeAtom(env, "entries");
    A.bin_op = makeAtom(env, "bin_op");
    A.op = makeAtom(env, "op");
    A.left = makeAtom(env, "left");
    A.right = makeAtom(env, "right");
    A.unary_op = makeAtom(env, "unary_op");
    A.operand = makeAtom(env, "operand");
    A.ternary = makeAtom(env, "ternary");
    A.cond_key = makeAtom(env, "cond");
    A.then_key = makeAtom(env, "then");
    A.else_key = makeAtom(env, "else");
    A.member = makeAtom(env, "member");
    A.field = makeAtom(env, "field");
    A.index = makeAtom(env, "index");
    A.assign = makeAtom(env, "assign");
    A.target = makeAtom(env, "target");
    A.value = makeAtom(env, "value");
    A.ph = makeAtom(env, "ph");

    A.kind = makeAtom(env, "kind");
    A.id = makeAtom(env, "id");
    A.expr = makeAtom(env, "expr");
    A.init = makeAtom(env, "init");
    A.call = makeAtom(env, "call");
    A.callee = makeAtom(env, "callee");
    A.state_refs = makeAtom(env, "state_refs");
    A.refs = makeAtom(env, "refs");
    A.deps = makeAtom(env, "deps");
    A.query = makeAtom(env, "query");
    A.mutation = makeAtom(env, "mutation");
    A.state = makeAtom(env, "state");

    A.text = makeAtom(env, "text");
    A.was_incomplete = makeAtom(env, "was_incomplete");
    A.var_atom = makeAtom(env, "var");
    A.unresolved = makeAtom(env, "unresolved");
    A.prose = makeAtom(env, "prose");
    A.code = makeAtom(env, "code");
    A.empty = makeAtom(env, "empty");

    return 0;
}

// ── Stack-First + ERTS Slab Bump Arena (Zero TLS!) ───────────────────────────

const BumpArena = struct {
    buf: []u8,
    pos: usize = 0,
    heap_slabs: [8]?[*]u8 = [_]?[*]u8{null} ** 8,
    slab_count: usize = 0,

    pub fn init(stack_buf: []u8) BumpArena {
        return .{ .buf = stack_buf, .pos = 0 };
    }

    pub fn deinit(self: *BumpArena) void {
        for (0..self.slab_count) |i| {
            nif_free(self.heap_slabs[i]);
        }
    }

    pub fn alloc(self: *BumpArena, comptime T: type, count: usize) []T {
        if (count == 0) return &[_]T{};
        const align_mask: usize = @alignOf(T) - 1;
        const aligned_pos = (self.pos + align_mask) & ~align_mask;
        const byte_len = count * @sizeOf(T);
        if (aligned_pos + byte_len <= self.buf.len) {
            self.pos = aligned_pos + byte_len;
            const ptr: [*]T = @ptrCast(@alignCast(self.buf.ptr + aligned_pos));
            return ptr[0..count];
        }

        // Allocate a new slab from ERTS NIF allocator
        const new_slab_size = @max(self.buf.len * 2, byte_len + 65536);
        const raw_ptr = nif_alloc(new_slab_size) orelse @panic("OpenUILang.ZigNIF: out of memory");
        if (self.slab_count < self.heap_slabs.len) {
            self.heap_slabs[self.slab_count] = raw_ptr;
            self.slab_count += 1;
        }
        self.buf = raw_ptr[0..new_slab_size];
        self.pos = byte_len;
        const ptr: [*]T = @ptrCast(@alignCast(raw_ptr));
        return ptr[0..count];
    }
};

fn Vec(comptime T: type) type {
    return struct {
        items: []T = &[_]T{},
        cap: usize = 0,
        arena: *BumpArena,

        pub fn init(arena: *BumpArena, initial_cap: usize) @This() {
            if (initial_cap == 0) return .{ .arena = arena };
            const mem = arena.alloc(T, initial_cap);
            return .{ .items = mem[0..0], .cap = initial_cap, .arena = arena };
        }

        pub fn append(self: *@This(), item: T) void {
            if (self.items.len == self.cap) {
                const new_cap = if (self.cap == 0) 16 else self.cap * 2;
                const new_mem = self.arena.alloc(T, new_cap);
                if (self.items.len > 0) {
                    @memcpy(new_mem[0..self.items.len], self.items);
                }
                self.items.ptr = new_mem.ptr;
                self.cap = new_cap;
            }
            self.items.ptr[self.items.len] = item;
            self.items.len += 1;
        }

        pub fn appendSlice(self: *@This(), slice: []const T) void {
            if (slice.len == 0) return;
            if (self.items.len + slice.len > self.cap) {
                var new_cap = if (self.cap == 0) 32 else self.cap * 2;
                while (new_cap < self.items.len + slice.len) new_cap *= 2;
                const new_mem = self.arena.alloc(T, new_cap);
                if (self.items.len > 0) {
                    @memcpy(new_mem[0..self.items.len], self.items);
                }
                self.items.ptr = new_mem.ptr;
                self.cap = new_cap;
            }
            @memcpy(self.items.ptr[self.items.len .. self.items.len + slice.len], slice);
            self.items.len += slice.len;
        }
    };
}

// ── String & Comment Preprocessing ───────────────────────────────────────────

inline fn isAsciiWs(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

inline fn isHorizWs(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r';
}

fn trimAscii(s: []const u8) []const u8 {
    var start: usize = 0;
    while (start < s.len and isAsciiWs(s[start])) : (start += 1) {}
    var end: usize = s.len;
    while (end > start and isAsciiWs(s[end - 1])) : (end -= 1) {}
    return s[start..end];
}

fn trimTrailingHoriz(s: []const u8) []const u8 {
    var end: usize = s.len;
    while (end > 0 and isHorizWs(s[end - 1])) : (end -= 1) {}
    return s[0..end];
}

fn findFence(input: []const u8, start_idx: usize) ?usize {
    var i = start_idx;
    while (i < input.len) {
        const c = input[i];
        if (c == '"') {
            i += 1;
            while (i < input.len) {
                if (input[i] == '\\') {
                    i += 2;
                } else if (input[i] == '"') {
                    i += 1;
                    break;
                } else {
                    i += 1;
                }
            }
        } else if (c == '`' and i + 2 < input.len and input[i + 1] == '`' and input[i + 2] == '`') {
            return i;
        } else {
            i += 1;
        }
    }
    return null;
}

fn stripFences(arena: *BumpArena, input: []const u8) []const u8 {
    if (std.mem.indexOf(u8, input, "```") == null) {
        return input;
    }

    var blocks = Vec([]const u8).init(arena, 4);
    var pos: usize = 0;

    while (pos < input.len) {
        const fence_start = findFence(input, pos) orelse break;
        const after_open = fence_start + 3;
        if (std.mem.indexOfScalarPos(u8, input, after_open, '\n')) |nl_pos| {
            const body_start = nl_pos + 1;
            if (findFence(input, body_start)) |close_pos| {
                blocks.append(input[body_start..close_pos]);
                pos = close_pos + 3;
            } else {
                blocks.append(input[body_start..input.len]);
                break;
            }
        } else {
            // Streaming: no newline after opening fence yet -> empty block
            blocks.append("");
            break;
        }
    }

    if (blocks.items.len > 0) {
        if (blocks.items.len == 1) return blocks.items[0];
        var out = Vec(u8).init(arena, input.len);
        for (blocks.items, 0..) |b, idx| {
            if (idx > 0) out.append('\n');
            out.appendSlice(b);
        }
        return out.items;
    }

    if (std.mem.startsWith(u8, input, "```")) {
        const rest = input[3..];
        const body = if (std.mem.indexOfScalar(u8, rest, '\n')) |nl| rest[nl + 1 ..] else rest;
        if (std.mem.lastIndexOf(u8, body, "```")) |last_pos| {
            return body[0..last_pos];
        }
        return body;
    }

    return input;
}

fn stripComments(arena: *BumpArena, input: []const u8) []const u8 {
    // Fast check: if neither '#' nor '//' appears in input, return input unchanged!
    if (std.mem.indexOfScalar(u8, input, '#') == null and std.mem.indexOf(u8, input, "//") == null) {
        return input;
    }

    var out = Vec(u8).init(arena, input.len);
    var in_str: u8 = 0;
    var line_start: usize = 0;
    var first_line = true;

    while (line_start <= input.len) {
        const nl_opt = std.mem.indexOfScalarPos(u8, input, line_start, '\n');
        const line_end = nl_opt orelse input.len;
        const line = input[line_start..line_end];

        if (!first_line) out.append('\n');
        first_line = false;

        var i: usize = 0;
        var stripped_line = line;
        while (i < line.len) {
            const c = line[i];
            if (in_str != 0) {
                if (c == '\\' and i + 1 < line.len) {
                    i += 2;
                } else if (c == in_str) {
                    in_str = 0;
                    i += 1;
                } else {
                    i += 1;
                }
            } else {
                if (c == '"' or c == '\'') {
                    in_str = c;
                    i += 1;
                } else if (c == '/' and i + 1 < line.len and line[i + 1] == '/') {
                    stripped_line = trimTrailingHoriz(line[0..i]);
                    in_str = 0;
                    break;
                } else if (c == '#') {
                    stripped_line = trimTrailingHoriz(line[0..i]);
                    in_str = 0;
                    break;
                } else {
                    i += 1;
                }
            }
        }

        out.appendSlice(stripped_line);

        if (nl_opt) |nl| {
            line_start = nl + 1;
        } else {
            break;
        }
    }

    return out.items;
}

fn preprocessSlice(arena: *BumpArena, input: []const u8) []const u8 {
    const t1 = trimAscii(input);
    if (t1.len == 0) return t1;
    const f = stripFences(arena, t1);
    const c = stripComments(arena, f);
    return trimAscii(c);
}

const AutoCloseResult = struct {
    text: []const u8,
    was_incomplete: bool,
};

fn autoCloseSlice(arena: *BumpArena, input: []const u8) AutoCloseResult {
    var stack = Vec(u8).init(arena, 32);
    var in_str: u8 = 0;
    var esc = false;

    for (input) |c| {
        if (esc) {
            esc = false;
            continue;
        }
        if (in_str != 0) {
            if (c == '\\') {
                esc = true;
            } else if (c == in_str) {
                in_str = 0;
            }
        } else {
            switch (c) {
                '"', '\'' => in_str = c,
                '(', '[', '{' => stack.append(c),
                ')' => {
                    if (stack.items.len > 0 and stack.items[stack.items.len - 1] == '(') {
                        stack.items.len -= 1;
                    }
                },
                ']' => {
                    if (stack.items.len > 0 and stack.items[stack.items.len - 1] == '[') {
                        stack.items.len -= 1;
                    }
                },
                '}' => {
                    if (stack.items.len > 0 and stack.items[stack.items.len - 1] == '{') {
                        stack.items.len -= 1;
                    }
                },
                else => {},
            }
        }
    }

    const was_incomplete = (in_str != 0) or (stack.items.len > 0);
    if (!was_incomplete) {
        return .{ .text = input, .was_incomplete = false };
    }

    var out = Vec(u8).init(arena, input.len + stack.items.len + 2);
    out.appendSlice(input);
    if (in_str != 0 and esc) out.append('\\');
    if (in_str != 0) out.append(in_str);

    var idx = stack.items.len;
    while (idx > 0) {
        idx -= 1;
        const close_ch: u8 = switch (stack.items[idx]) {
            '(' => ')',
            '[' => ']',
            '{' => '}',
            else => ')',
        };
        out.append(close_ch);
    }

    return .{ .text = out.items, .was_incomplete = true };
}

// ── Native Lexer ─────────────────────────────────────────────────────────────

const TokenTag = enum(u8) {
    newline,
    eof,
    lparen,
    rparen,
    lbrack,
    rbrack,
    lbrace,
    rbrace,
    comma,
    colon,
    dot,
    question,
    plus,
    minus,
    star,
    slash,
    percent,
    eq_eq,
    equals,
    not_eq,
    not_tok,
    greater_eq,
    greater,
    less_eq,
    less,
    and_tok,
    or_tok,
    true_tok,
    false_tok,
    null_tok,
    str,
    num_int,
    num_float,
    ident,
    type_tok,
    state_var,
    builtin_call,
};

const ZigToken = struct {
    tag: TokenTag,
    slice: []const u8 = "",
    int_val: i64 = 0,
    float_val: f64 = 0.0,
};

inline fn isIdentStart(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

inline fn isIdentCont(c: u8) bool {
    return isIdentStart(c) or (c >= '0' and c <= '9');
}

inline fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

inline fn isHexDigit(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

inline fn isAfterValueTag(tag: TokenTag) bool {
    return switch (tag) {
        .num_int,
        .num_float,
        .str,
        .ident,
        .type_tok,
        .rparen,
        .rbrack,
        .true_tok,
        .false_tok,
        .null_tok,
        .state_var,
        .builtin_call,
        => true,
        else => false,
    };
}

fn scanDoubleQuoted(arena: *BumpArena, src: []const u8, start_pos: usize) struct { str: []const u8, next_pos: usize } {
    // Fast scan for closing quote without escapes
    var i = start_pos;
    while (i < src.len) : (i += 1) {
        const c = src[i];
        if (c == '"') {
            return .{ .str = src[start_pos..i], .next_pos = i + 1 };
        }
        if (c == '\\') break;
    }
    if (i >= src.len) {
        return .{ .str = src[start_pos..src.len], .next_pos = src.len };
    }

    // Slow path: has escape sequences
    var out = Vec(u8).init(arena, (src.len - start_pos) + 8);
    if (i > start_pos) {
        out.appendSlice(src[start_pos..i]);
    }

    while (i < src.len) {
        const c = src[i];
        if (c == '"') {
            return .{ .str = out.items, .next_pos = i + 1 };
        }
        if (c == '\\') {
            if (i + 1 >= src.len) {
                out.append('\\');
                return .{ .str = out.items, .next_pos = src.len };
            }
            const esc = src[i + 1];
            if (esc == 'u' and i + 5 < src.len and isHexDigit(src[i + 2])) {
                const hex = src[i + 2 .. i + 6];
                if (std.fmt.parseInt(u21, hex, 16)) |cp| {
                    var utf8_buf: [4]u8 = undefined;
                    if (std.unicode.utf8Encode(cp, &utf8_buf)) |len| {
                        out.appendSlice(utf8_buf[0..len]);
                        i += 6;
                        continue;
                    } else |_| {}
                } else |_| {}
                out.appendSlice(src[i .. i + 6]);
                i += 6;
                continue;
            }
            const unescaped: u8 = switch (esc) {
                '"' => '"',
                '\\' => '\\',
                '/' => '/',
                'b' => 0x08,
                'f' => 0x0C,
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                else => esc,
            };
            out.append(unescaped);
            i += 2;
        } else {
            out.append(c);
            i += 1;
        }
    }

    return .{ .str = out.items, .next_pos = src.len };
}

fn scanSingleQuoted(arena: *BumpArena, src: []const u8, start_pos: usize) struct { str: []const u8, next_pos: usize } {
    var i = start_pos;
    while (i < src.len) : (i += 1) {
        const c = src[i];
        if (c == '\'') {
            return .{ .str = src[start_pos..i], .next_pos = i + 1 };
        }
        if (c == '\\') break;
    }
    if (i >= src.len) {
        return .{ .str = src[start_pos..src.len], .next_pos = src.len };
    }

    var out = Vec(u8).init(arena, (src.len - start_pos) + 8);
    if (i > start_pos) {
        out.appendSlice(src[start_pos..i]);
    }

    while (i < src.len) {
        const c = src[i];
        if (c == '\'') {
            return .{ .str = out.items, .next_pos = i + 1 };
        }
        if (c == '\\') {
            if (i + 1 >= src.len) {
                return .{ .str = out.items, .next_pos = src.len };
            }
            const esc = src[i + 1];
            const unescaped: u8 = switch (esc) {
                '\'' => '\'',
                '\\' => '\\',
                'n' => '\n',
                't' => '\t',
                else => esc,
            };
            out.append(unescaped);
            i += 2;
        } else {
            out.append(c);
            i += 1;
        }
    }

    return .{ .str = out.items, .next_pos = src.len };
}

fn scanNumber(src: []const u8, start_pos: usize) struct { tok: ZigToken, next_pos: usize } {
    var i = start_pos;
    if (i < src.len and src[i] == '-') i += 1;
    while (i < src.len and isDigit(src[i])) : (i += 1) {}

    var has_float = false;
    if (i + 1 < src.len and src[i] == '.' and isDigit(src[i + 1])) {
        has_float = true;
        i += 2;
        while (i < src.len and isDigit(src[i])) : (i += 1) {}
    }

    if (i < src.len and (src[i] == 'e' or src[i] == 'E')) {
        has_float = true;
        i += 1;
        if (i < src.len and (src[i] == '+' or src[i] == '-')) i += 1;
        while (i < src.len and isDigit(src[i])) : (i += 1) {}
    }

    const num_slice = src[start_pos..i];

    // Check unit suffix (k/K, m/M, g/G/b/B) if not followed by ident/digit char
    var mult: i64 = 1;
    if (i < src.len) {
        const u = src[i];
        const next_is_ident = (i + 1 < src.len) and isIdentCont(src[i + 1]);
        if (!next_is_ident) {
            switch (u) {
                'k', 'K' => {
                    mult = 1_000;
                    i += 1;
                },
                'm', 'M' => {
                    mult = 1_000_000;
                    i += 1;
                },
                'g', 'G', 'b', 'B' => {
                    mult = 1_000_000_000;
                    i += 1;
                },
                else => {},
            }
        }
    }

    if (!has_float) {
        const parsed = parseIntFast(num_slice);
        return .{
            .tok = .{ .tag = .num_int, .slice = src[start_pos..i], .int_val = parsed *% mult },
            .next_pos = i,
        };
    } else {
        const parsed = nif_parse_double(num_slice.ptr, num_slice.len);
        const val = parsed * @as(f64, @floatFromInt(mult));
        const trunc_val = @trunc(val);
        if (val == trunc_val and val >= -9007199254740992.0 and val <= 9007199254740992.0) {
            return .{
                .tok = .{ .tag = .num_int, .slice = src[start_pos..i], .int_val = @intFromFloat(trunc_val) },
                .next_pos = i,
            };
        }
        return .{
            .tok = .{ .tag = .num_float, .slice = src[start_pos..i], .float_val = val },
            .next_pos = i,
        };
    }
}

fn parseIntFast(s: []const u8) i64 {
    if (s.len == 0) return 0;
    var idx: usize = 0;
    var neg = false;
    if (s[0] == '-') {
        neg = true;
        idx = 1;
    } else if (s[0] == '+') {
        idx = 1;
    }
    var acc: i64 = 0;
    while (idx < s.len) : (idx += 1) {
        const c = s[idx];
        if (c < '0' or c > '9') break;
        acc = acc *% 10 +% @as(i64, @intCast(c - '0'));
    }
    return if (neg) -%acc else acc;
}

fn tokenizeSlice(arena: *BumpArena, src: []const u8) []ZigToken {
    var toks = Vec(ZigToken).init(arena, (src.len / 4) + 16);
    var i: usize = 0;

    while (i < src.len) {
        const c = src[i];
        switch (c) {
            ' ', '\t', '\r' => i += 1,
            '\n' => {
                toks.append(.{ .tag = .newline });
                i += 1;
            },
            '(' => {
                toks.append(.{ .tag = .lparen });
                i += 1;
            },
            ')' => {
                toks.append(.{ .tag = .rparen });
                i += 1;
            },
            '[' => {
                toks.append(.{ .tag = .lbrack });
                i += 1;
            },
            ']' => {
                toks.append(.{ .tag = .rbrack });
                i += 1;
            },
            '{' => {
                toks.append(.{ .tag = .lbrace });
                i += 1;
            },
            '}' => {
                toks.append(.{ .tag = .rbrace });
                i += 1;
            },
            ',' => {
                toks.append(.{ .tag = .comma });
                i += 1;
            },
            ':' => {
                toks.append(.{ .tag = .colon });
                i += 1;
            },
            '.' => {
                toks.append(.{ .tag = .dot });
                i += 1;
            },
            '?' => {
                toks.append(.{ .tag = .question });
                i += 1;
            },
            '+' => {
                toks.append(.{ .tag = .plus });
                i += 1;
            },
            '*' => {
                toks.append(.{ .tag = .star });
                i += 1;
            },
            '/' => {
                toks.append(.{ .tag = .slash });
                i += 1;
            },
            '%' => {
                toks.append(.{ .tag = .percent });
                i += 1;
            },
            '=' => {
                if (i + 1 < src.len and src[i + 1] == '=') {
                    toks.append(.{ .tag = .eq_eq });
                    i += 2;
                } else {
                    toks.append(.{ .tag = .equals });
                    i += 1;
                }
            },
            '!' => {
                if (i + 1 < src.len and src[i + 1] == '=') {
                    toks.append(.{ .tag = .not_eq });
                    i += 2;
                } else {
                    toks.append(.{ .tag = .not_tok });
                    i += 1;
                }
            },
            '>' => {
                if (i + 1 < src.len and src[i + 1] == '=') {
                    toks.append(.{ .tag = .greater_eq });
                    i += 2;
                } else {
                    toks.append(.{ .tag = .greater });
                    i += 1;
                }
            },
            '<' => {
                if (i + 1 < src.len and src[i + 1] == '=') {
                    toks.append(.{ .tag = .less_eq });
                    i += 2;
                } else {
                    toks.append(.{ .tag = .less });
                    i += 1;
                }
            },
            '&' => {
                if (i + 1 < src.len and src[i + 1] == '&') {
                    toks.append(.{ .tag = .and_tok });
                    i += 2;
                } else {
                    toks.append(.{ .tag = .and_tok });
                    i += 1;
                }
            },
            '|' => {
                if (i + 1 < src.len and src[i + 1] == '|') {
                    toks.append(.{ .tag = .or_tok });
                    i += 2;
                } else {
                    toks.append(.{ .tag = .or_tok });
                    i += 1;
                }
            },
            '"' => {
                const res = scanDoubleQuoted(arena, src, i + 1);
                toks.append(.{ .tag = .str, .slice = res.str });
                i = res.next_pos;
            },
            '\'' => {
                const res = scanSingleQuoted(arena, src, i + 1);
                toks.append(.{ .tag = .str, .slice = res.str });
                i = res.next_pos;
            },
            '-' => {
                if (i + 1 < src.len and isDigit(src[i + 1])) {
                    const after_val = if (toks.items.len > 0)
                        isAfterValueTag(toks.items[toks.items.len - 1].tag)
                    else
                        false;
                    if (after_val) {
                        toks.append(.{ .tag = .minus });
                        i += 1;
                    } else {
                        const res = scanNumber(src, i);
                        toks.append(res.tok);
                        i = res.next_pos;
                    }
                } else {
                    toks.append(.{ .tag = .minus });
                    i += 1;
                }
            },
            '0'...'9' => {
                const res = scanNumber(src, i);
                toks.append(res.tok);
                i = res.next_pos;
            },
            '$' => {
                if (i + 1 < src.len and isIdentStart(src[i + 1])) {
                    var end = i + 2;
                    while (end < src.len and isIdentCont(src[end])) : (end += 1) {}
                    toks.append(.{ .tag = .state_var, .slice = src[i..end] });
                    i = end;
                } else {
                    i += 1;
                }
            },
            '@' => {
                if (i + 1 < src.len and isIdentStart(src[i + 1])) {
                    var end = i + 2;
                    while (end < src.len and isIdentCont(src[end])) : (end += 1) {}
                    toks.append(.{ .tag = .builtin_call, .slice = src[i + 1 .. end] });
                    i = end;
                } else {
                    i += 1;
                }
            },
            'a'...'z', 'A'...'Z', '_' => {
                var end = i + 1;
                while (end < src.len and isIdentCont(src[end])) : (end += 1) {}
                const word = src[i..end];
                if (std.mem.eql(u8, word, "true")) {
                    toks.append(.{ .tag = .true_tok });
                } else if (std.mem.eql(u8, word, "false")) {
                    toks.append(.{ .tag = .false_tok });
                } else if (std.mem.eql(u8, word, "null")) {
                    toks.append(.{ .tag = .null_tok });
                } else if (c >= 'A' and c <= 'Z') {
                    toks.append(.{ .tag = .type_tok, .slice = word });
                } else {
                    toks.append(.{ .tag = .ident, .slice = word });
                }
                i = end;
            },
            else => {
                // Skip unknown byte or UTF-8 sequence
                const cp_len = std.unicode.utf8ByteSequenceLength(c) catch 1;
                i += if (i + cp_len <= src.len) cp_len else 1;
            },
        }
    }

    toks.append(.{ .tag = .eof });
    return toks.items;
}

fn tokenToTerm(env: ?*ErlNifEnv, tok: ZigToken) ERL_NIF_TERM {
    return switch (tok.tag) {
        .newline => A.newline,
        .eof => A.eof,
        .lparen => A.lparen,
        .rparen => A.rparen,
        .lbrack => A.lbrack,
        .rbrack => A.rbrack,
        .lbrace => A.lbrace,
        .rbrace => A.rbrace,
        .comma => A.comma,
        .colon => A.colon,
        .dot => A.dot,
        .question => A.question,
        .plus => A.plus,
        .minus => A.minus,
        .star => A.star,
        .slash => A.slash,
        .percent => A.percent,
        .eq_eq => A.eq_eq,
        .equals => A.equals,
        .not_eq => A.not_eq,
        .not_tok => A.not_tok,
        .greater_eq => A.greater_eq,
        .greater => A.greater,
        .less_eq => A.less_eq,
        .less => A.less,
        .and_tok => A.and_tok,
        .or_tok => A.or_tok,
        .true_tok => A.true_atom,
        .false_tok => A.false_atom,
        .null_tok => A.null_atom,
        .str => nif_make_tuple2(env, A.str, makeBin(env, tok.slice)),
        .num_int => nif_make_tuple2(env, A.num, nif_make_int64(env, tok.int_val)),
        .num_float => nif_make_tuple2(env, A.num, nif_make_double(env, tok.float_val)),
        .ident => nif_make_tuple2(env, A.ident, makeBin(env, tok.slice)),
        .type_tok => nif_make_tuple2(env, A.type_tok, makeBin(env, tok.slice)),
        .state_var => nif_make_tuple2(env, A.state_var, makeBin(env, tok.slice)),
        .builtin_call => nif_make_tuple2(env, A.builtin_call, makeBin(env, tok.slice)),
    };
}

// ── Statement Splitter ───────────────────────────────────────────────────────

const RawStmt = struct {
    id: []const u8,
    id_tag: TokenTag,
    tokens: []const ZigToken,
};

fn splitTokens(arena: *BumpArena, tokens: []const ZigToken) []RawStmt {
    var stmts = Vec(RawStmt).init(arena, 32);
    var i: usize = 0;

    while (i < tokens.len) {
        const tag = tokens[i].tag;
        if (tag == .eof) break;
        if (tag == .newline) {
            i += 1;
            continue;
        }

        if ((tag == .ident or tag == .type_tok or tag == .state_var) and
            i + 1 < tokens.len and tokens[i + 1].tag == .equals)
        {
            const id_slice = tokens[i].slice;
            i += 2;
            var expr_toks = Vec(ZigToken).init(arena, 16);
            var depth: i32 = 0;
            var tdepth: i32 = 0;

            while (i < tokens.len) {
                const t = tokens[i].tag;
                if (t == .eof) break;
                if (t == .newline) {
                    if (depth <= 0 and tdepth <= 0) {
                        var peek_idx = i + 1;
                        while (peek_idx < tokens.len and tokens[peek_idx].tag == .newline) : (peek_idx += 1) {}
                        const next_t = if (peek_idx < tokens.len) tokens[peek_idx].tag else .eof;
                        if (next_t == .question or (next_t == .colon and tdepth > 0)) {
                            i += 1;
                            continue;
                        } else {
                            break;
                        }
                    } else {
                        i += 1;
                        continue;
                    }
                }

                switch (t) {
                    .lparen, .lbrack, .lbrace => depth += 1,
                    .rparen, .rbrack, .rbrace => {
                        if (depth > 0) depth -= 1;
                    },
                    .question => {
                        if (depth == 0) tdepth += 1;
                    },
                    .colon => {
                        if (depth == 0 and tdepth > 0) tdepth -= 1;
                    },
                    else => {},
                }
                expr_toks.append(tokens[i]);
                i += 1;
            }

            if (expr_toks.items.len > 0) {
                stmts.append(.{
                    .id = id_slice,
                    .id_tag = tag,
                    .tokens = expr_toks.items,
                });
            }
        } else {
            // Skip to newline or eof
            i += 1;
            while (i < tokens.len and tokens[i].tag != .newline and tokens[i].tag != .eof) : (i += 1) {}
        }
    }

    return stmts.items;
}

// ── Builtin Check & Pratt Expression Parser ──────────────────────────────────

fn isBuiltin(name: []const u8) bool {
    const builtins = [_][]const u8{
        "Count",       "First",   "Last",  "Sum",   "Avg",   "Min",
        "Max",         "Sort",    "Filter","Round", "Abs",   "Floor",
        "Ceil",        "Each",    "Run",   "ToAssistant", "OpenUrl",
        "Set",         "Reset",   "Action",
    };
    for (builtins) |b| {
        if (std.mem.eql(u8, name, b)) return true;
    }
    return false;
}

const PREC_TERNARY: u8 = 1;
const PREC_OR: u8 = 2;
const PREC_AND: u8 = 3;
const PREC_EQ: u8 = 4;
const PREC_CMP: u8 = 5;
const PREC_ADD: u8 = 6;
const PREC_MUL: u8 = 7;
const PREC_UNARY: u8 = 8;
const PREC_MEMBER: u8 = 9;

inline fn infixPrec(tag: TokenTag) u8 {
    return switch (tag) {
        .question => PREC_TERNARY,
        .or_tok => PREC_OR,
        .and_tok => PREC_AND,
        .eq_eq, .not_eq => PREC_EQ,
        .greater, .less, .greater_eq, .less_eq => PREC_CMP,
        .plus, .minus => PREC_ADD,
        .star, .slash, .percent => PREC_MUL,
        .dot, .lbrack => PREC_MEMBER,
        else => 0,
    };
}

fn formatIntToSlice(buf: []u8, val: i64) []const u8 {
    if (val == 0) {
        buf[0] = '0';
        return buf[0..1];
    }
    var v: u64 = if (val < 0) @intCast(-val) else @intCast(val);
    var i: usize = buf.len;
    while (v > 0 and i > 0) {
        i -= 1;
        buf[i] = @intCast('0' + (v % 10));
        v /= 10;
    }
    if (val < 0 and i > 0) {
        i -= 1;
        buf[i] = '-';
    }
    return buf[i..buf.len];
}

fn addUniqueRef(vec: *Vec([]const u8), item: []const u8) void {
    for (vec.items) |existing| {
        if (std.mem.eql(u8, existing, item)) return;
    }
    vec.append(item);
}

const ExprParser = struct {
    env: ?*ErlNifEnv,
    arena: *BumpArena,
    tokens: []const ZigToken,
    pos: usize = 0,
    need_refs: bool,
    refs: Vec([]const u8),
    state_refs: Vec([]const u8),
    track_arg1_deps: bool = false,
    in_arg1: bool = false,
    arg1_deps: Vec([]const u8),
    top_comp_name: []const u8 = "",
    top_comp_args: []const ERL_NIF_TERM = &[_]ERL_NIF_TERM{},
    is_top_comp: bool = false,

    pub fn init(env: ?*ErlNifEnv, arena: *BumpArena, tokens: []const ZigToken, need_refs: bool) ExprParser {
        return .{
            .env = env,
            .arena = arena,
            .tokens = tokens,
            .need_refs = need_refs,
            .refs = Vec([]const u8).init(arena, if (need_refs) 8 else 0),
            .state_refs = Vec([]const u8).init(arena, 8),
            .arg1_deps = Vec([]const u8).init(arena, 4),
        };
    }

    inline fn recordRef(self: *ExprParser, name: []const u8) void {
        if (self.need_refs) {
            addUniqueRef(&self.refs, name);
        }
    }

    inline fn recordStateRef(self: *ExprParser, name: []const u8) void {
        addUniqueRef(&self.state_refs, name);
        if (self.in_arg1) {
            addUniqueRef(&self.arg1_deps, name);
        }
    }

    inline fn eat(self: *ExprParser, tag: TokenTag) void {
        if (self.pos < self.tokens.len and self.tokens[self.pos].tag == tag) {
            self.pos += 1;
        }
    }

    pub fn parseExpr(self: *ExprParser, min_prec: u8, at_root: bool) ERL_NIF_TERM {
        var left = self.parsePrefix(at_root);
        while (self.pos < self.tokens.len) {
            const prec = infixPrec(self.tokens[self.pos].tag);
            if (prec > min_prec) {
                self.is_top_comp = false;
                left = self.parseInfix(left);
            } else {
                break;
            }
        }
        return left;
    }

    fn parsePrefix(self: *ExprParser, at_root: bool) ERL_NIF_TERM {
        if (self.pos >= self.tokens.len) {
            return A.null_atom;
        }

        const tok = self.tokens[self.pos];
        switch (tok.tag) {
            .str => {
                self.pos += 1;
                return nif_make_tuple2(self.env, A.str, makeBin(self.env, tok.slice));
            },
            .num_int => {
                self.pos += 1;
                return nif_make_tuple2(self.env, A.num, nif_make_int64(self.env, tok.int_val));
            },
            .num_float => {
                self.pos += 1;
                return nif_make_tuple2(self.env, A.num, nif_make_double(self.env, tok.float_val));
            },
            .true_tok => {
                self.pos += 1;
                return A.true_atom;
            },
            .false_tok => {
                self.pos += 1;
                return A.false_atom;
            },
            .null_tok => {
                self.pos += 1;
                return A.null_atom;
            },
            .lbrack => {
                self.pos += 1;
                return self.parseArr();
            },
            .lbrace => {
                self.pos += 1;
                return self.parseObj();
            },
            .state_var => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .equals) {
                    self.pos += 2;
                    const val = self.parseExpr(0, false);
                    return nif_make_tuple3(self.env, A.assign, makeBin(self.env, tok.slice), val);
                } else {
                    self.pos += 1;
                    self.recordStateRef(tok.slice);
                    return nif_make_tuple2(self.env, A.state_ref, makeBin(self.env, tok.slice));
                }
            },
            .type_tok => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    if (!isBuiltin(tok.slice) or std.mem.eql(u8, tok.slice, "Action")) {
                        self.pos += 2;
                        const is_top_query = at_root and std.mem.eql(u8, tok.slice, "Query");
                        const args_slice = self.parseArgs(is_top_query);
                        if (at_root) {
                            self.is_top_comp = true;
                            self.top_comp_name = tok.slice;
                        }
                        return nif_make_tuple3(self.env, A.comp, makeBin(self.env, tok.slice), makeList(self.env, args_slice));
                    } else {
                        self.pos += 1;
                        self.recordRef(tok.slice);
                        return nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice));
                    }
                } else {
                    self.pos += 1;
                    self.recordRef(tok.slice);
                    return nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice));
                }
            },
            .builtin_call => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    self.pos += 2;
                    const args_slice = self.parseArgs(false);
                    if (!isBuiltin(tok.slice)) {
                        return nif_make_tuple4(self.env, A.comp, makeBin(self.env, tok.slice), makeList(self.env, args_slice), A.true_atom);
                    } else {
                        return nif_make_tuple3(self.env, A.comp, makeBin(self.env, tok.slice), makeList(self.env, args_slice));
                    }
                } else {
                    self.pos += 1;
                    self.recordRef(tok.slice);
                    return nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice));
                }
            },
            .ident => {
                self.pos += 1;
                self.recordRef(tok.slice);
                return nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice));
            },
            .not_tok => {
                self.pos += 1;
                const operand = self.parseExpr(PREC_UNARY, false);
                return nif_make_tuple3(self.env, A.unary_op, A.not_tok, operand);
            },
            .minus => {
                self.pos += 1;
                const operand = self.parseExpr(PREC_UNARY, false);
                return nif_make_tuple3(self.env, A.unary_op, A.minus, operand);
            },
            .lparen => {
                self.pos += 1;
                const inner = self.parseExpr(0, false);
                self.eat(.rparen);
                return inner;
            },
            else => {
                self.pos += 1;
                return A.null_atom;
            },
        }
    }

    fn parseInfix(self: *ExprParser, left: ERL_NIF_TERM) ERL_NIF_TERM {
        const tok = self.tokens[self.pos];
        self.pos += 1;

        switch (tok.tag) {
            .plus => {
                const right = self.parseExpr(PREC_ADD, false);
                return nif_make_tuple4(self.env, A.bin_op, A.plus, left, right);
            },
            .minus => {
                const right = self.parseExpr(PREC_ADD, false);
                return nif_make_tuple4(self.env, A.bin_op, A.minus, left, right);
            },
            .star => {
                const right = self.parseExpr(PREC_MUL, false);
                return nif_make_tuple4(self.env, A.bin_op, A.star, left, right);
            },
            .slash => {
                const right = self.parseExpr(PREC_MUL, false);
                return nif_make_tuple4(self.env, A.bin_op, A.slash, left, right);
            },
            .percent => {
                const right = self.parseExpr(PREC_MUL, false);
                return nif_make_tuple4(self.env, A.bin_op, A.percent, left, right);
            },
            .eq_eq => {
                const right = self.parseExpr(PREC_EQ, false);
                return nif_make_tuple4(self.env, A.bin_op, A.eq_eq, left, right);
            },
            .not_eq => {
                const right = self.parseExpr(PREC_EQ, false);
                return nif_make_tuple4(self.env, A.bin_op, A.not_eq, left, right);
            },
            .greater => {
                const right = self.parseExpr(PREC_CMP, false);
                return nif_make_tuple4(self.env, A.bin_op, A.greater, left, right);
            },
            .less => {
                const right = self.parseExpr(PREC_CMP, false);
                return nif_make_tuple4(self.env, A.bin_op, A.less, left, right);
            },
            .greater_eq => {
                const right = self.parseExpr(PREC_CMP, false);
                return nif_make_tuple4(self.env, A.bin_op, A.greater_eq, left, right);
            },
            .less_eq => {
                const right = self.parseExpr(PREC_CMP, false);
                return nif_make_tuple4(self.env, A.bin_op, A.less_eq, left, right);
            },
            .and_tok => {
                const right = self.parseExpr(PREC_AND, false);
                return nif_make_tuple4(self.env, A.bin_op, A.and_tok, left, right);
            },
            .or_tok => {
                const right = self.parseExpr(PREC_OR, false);
                return nif_make_tuple4(self.env, A.bin_op, A.or_tok, left, right);
            },
            .question => {
                const then_node = self.parseExpr(0, false);
                self.eat(.colon);
                const else_node = self.parseExpr(0, false);
                return nif_make_tuple4(self.env, A.ternary, left, then_node, else_node);
            },
            .dot => {
                const field_term = self.parseKeyOrField();
                return nif_make_tuple3(self.env, A.member, left, field_term);
            },
            .lbrack => {
                const idx_node = self.parseExpr(0, false);
                self.eat(.rbrack);
                return nif_make_tuple3(self.env, A.index, left, idx_node);
            },
            else => return left,
        }
    }

    fn parseArgs(self: *ExprParser, track_arg1: bool) []ERL_NIF_TERM {
        var acc = Vec(ERL_NIF_TERM).init(self.arena, 8);
        var arg_idx: usize = 0;
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rparen) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;

            const prev_in_arg1 = self.in_arg1;
            if (track_arg1 and arg_idx == 1) self.in_arg1 = true;
            const arg = self.parseExpr(0, false);
            self.in_arg1 = prev_in_arg1;

            self.eat(.comma);
            acc.append(arg);
            arg_idx += 1;
        }
        return acc.items;
    }

    fn parseArr(self: *ExprParser) ERL_NIF_TERM {
        var acc = Vec(ERL_NIF_TERM).init(self.arena, 8);
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rbrack) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;
            const el = self.parseExpr(0, false);
            self.eat(.comma);
            acc.append(el);
        }
        return nif_make_tuple2(self.env, A.arr, makeList(self.env, acc.items));
    }

    fn parseObj(self: *ExprParser) ERL_NIF_TERM {
        var acc = Vec(ERL_NIF_TERM).init(self.arena, 8);
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rbrace) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;
            const key_term = self.parseKeyOrField();
            self.eat(.colon);
            const val_term = self.parseExpr(0, false);
            self.eat(.comma);
            acc.append(nif_make_tuple2(self.env, key_term, val_term));
        }
        return nif_make_tuple2(self.env, A.obj, makeList(self.env, acc.items));
    }

    fn parseKeyOrField(self: *ExprParser) ERL_NIF_TERM {
        if (self.pos >= self.tokens.len) {
            return makeBin(self.env, "?");
        }
        const tok = self.tokens[self.pos];
        self.pos += 1;
        return switch (tok.tag) {
            .ident, .type_tok, .str => makeBin(self.env, tok.slice),
            .state_var => makeBin(self.env, if (tok.slice.len > 0 and tok.slice[0] == '$') tok.slice[1..] else tok.slice),
            .num_int => {
                var buf: [32]u8 = undefined;
                const s = formatIntToSlice(&buf, tok.int_val);
                return makeBin(self.env, s);
            },
            .num_float => {
                return makeBin(self.env, tok.slice);
            },
            else => makeBin(self.env, "?"),
        };
    }
};

fn slicesToTermList(env: ?*ErlNifEnv, arena: *BumpArena, slices: []const []const u8) ERL_NIF_TERM {
    if (slices.len == 0) return makeList(env, &[_]ERL_NIF_TERM{});
    var terms = arena.alloc(ERL_NIF_TERM, slices.len);
    for (slices, 0..) |s, i| {
        terms[i] = makeBin(env, s);
    }
    return makeList(env, terms);
}

// ── TUI Tuple AST Parser (Direct `parse_symbols`) ────────────────────────────

const TupleNode = struct {
    term: ERL_NIF_TERM,
    is_num_lit: bool = false,
    is_int: bool = false,
    int_val: i64 = 0,
    float_val: f64 = 0.0,
};

const TupleExprParser = struct {
    env: ?*ErlNifEnv,
    arena: *BumpArena,
    tokens: []const ZigToken,
    pos: usize = 0,

    inline fn eat(self: *TupleExprParser, tag: TokenTag) void {
        if (self.pos < self.tokens.len and self.tokens[self.pos].tag == tag) {
            self.pos += 1;
        }
    }

    pub fn parseExpr(self: *TupleExprParser, min_prec: u8) TupleNode {
        var left = self.parsePrefix();
        while (self.pos < self.tokens.len) {
            const prec = infixPrec(self.tokens[self.pos].tag);
            if (prec > min_prec) {
                left = self.parseInfix(left);
            } else {
                break;
            }
        }
        return left;
    }

    fn parsePrefix(self: *TupleExprParser) TupleNode {
        if (self.pos >= self.tokens.len) {
            return .{ .term = A.nil_atom };
        }
        const tok = self.tokens[self.pos];
        switch (tok.tag) {
            .str => {
                self.pos += 1;
                return .{ .term = makeBin(self.env, tok.slice) };
            },
            .num_int => {
                self.pos += 1;
                return .{ .term = nif_make_int64(self.env, tok.int_val), .is_num_lit = true, .is_int = true, .int_val = tok.int_val };
            },
            .num_float => {
                self.pos += 1;
                return .{ .term = nif_make_double(self.env, tok.float_val), .is_num_lit = true, .is_int = false, .float_val = tok.float_val };
            },
            .true_tok => {
                self.pos += 1;
                return .{ .term = A.true_atom };
            },
            .false_tok => {
                self.pos += 1;
                return .{ .term = A.false_atom };
            },
            .null_tok => {
                self.pos += 1;
                return .{ .term = A.nil_atom };
            },
            .lbrack => {
                self.pos += 1;
                var acc = Vec(ERL_NIF_TERM).init(self.arena, 8);
                while (self.pos < self.tokens.len) {
                    const t = self.tokens[self.pos].tag;
                    if (t == .rbrack) {
                        self.pos += 1;
                        break;
                    }
                    if (t == .eof) break;
                    const el = self.parseExpr(0);
                    self.eat(.comma);
                    acc.append(el.term);
                }
                return .{ .term = makeList(self.env, acc.items) };
            },
            .lbrace => {
                self.pos += 1;
                var keys = Vec(ERL_NIF_TERM).init(self.arena, 8);
                var vals = Vec(ERL_NIF_TERM).init(self.arena, 8);
                var key_slices = Vec([]const u8).init(self.arena, 8);
                while (self.pos < self.tokens.len) {
                    const t = self.tokens[self.pos].tag;
                    if (t == .rbrace) {
                        self.pos += 1;
                        break;
                    }
                    if (t == .eof) break;
                    const k_res = self.parseKeyOrFieldWithSlice();
                    self.eat(.colon);
                    const v_node = self.parseExpr(0);
                    self.eat(.comma);

                    var found_idx: ?usize = null;
                    for (key_slices.items, 0..) |ek, i| {
                        if (std.mem.eql(u8, ek, k_res.slice)) {
                            found_idx = i;
                            break;
                        }
                    }
                    if (found_idx) |fi| {
                        vals.items[fi] = v_node.term;
                    } else {
                        key_slices.append(k_res.slice);
                        keys.append(k_res.term);
                        vals.append(v_node.term);
                    }
                }
                return .{ .term = makeMap(self.env, keys.items, vals.items) };
            },
            .state_var => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .equals) {
                    self.pos += 2;
                    const val = self.parseExpr(0);
                    var keys = [_]ERL_NIF_TERM{ A.k, A.target, A.value };
                    var vals = [_]ERL_NIF_TERM{ A.assign, makeBin(self.env, tok.slice), val.term };
                    return .{ .term = makeMap(self.env, &keys, &vals) };
                } else {
                    self.pos += 1;
                    return .{ .term = nif_make_tuple2(self.env, A.var_atom, makeBin(self.env, tok.slice)) };
                }
            },
            .type_tok => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    if (!isBuiltin(tok.slice) or std.mem.eql(u8, tok.slice, "Action")) {
                        self.pos += 2;
                        const args = self.parseArgs();
                        return .{ .term = nif_make_tuple2(self.env, makeBin(self.env, tok.slice), makeList(self.env, args)) };
                    } else {
                        self.pos += 1;
                        return .{ .term = nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice)) };
                    }
                } else {
                    self.pos += 1;
                    return .{ .term = nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice)) };
                }
            },
            .builtin_call => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    self.pos += 2;
                    const args = self.parseArgs();
                    return .{ .term = nif_make_tuple2(self.env, makeBin(self.env, tok.slice), makeList(self.env, args)) };
                } else {
                    self.pos += 1;
                    return .{ .term = nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice)) };
                }
            },
            .ident => {
                self.pos += 1;
                return .{ .term = nif_make_tuple2(self.env, A.ref, makeBin(self.env, tok.slice)) };
            },
            .not_tok => {
                self.pos += 1;
                const op = self.parseExpr(PREC_UNARY);
                return .{ .term = nif_make_tuple3(self.env, A.unary_op, makeBin(self.env, "!"), op.term) };
            },
            .minus => {
                self.pos += 1;
                const op = self.parseExpr(PREC_UNARY);
                if (op.is_num_lit) {
                    if (op.is_int) {
                        return .{ .term = nif_make_int64(self.env, -op.int_val) };
                    } else {
                        return .{ .term = nif_make_double(self.env, -op.float_val) };
                    }
                }
                return .{ .term = nif_make_tuple3(self.env, A.unary_op, makeBin(self.env, "-"), op.term) };
            },
            .lparen => {
                self.pos += 1;
                const inner = self.parseExpr(0);
                self.eat(.rparen);
                return inner;
            },
            else => {
                self.pos += 1;
                return .{ .term = A.nil_atom };
            },
        }
    }

    fn parseInfix(self: *TupleExprParser, left: TupleNode) TupleNode {
        const tok = self.tokens[self.pos];
        self.pos += 1;
        switch (tok.tag) {
            .plus => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "+"), left.term, self.parseExpr(PREC_ADD).term) },
            .minus => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "-"), left.term, self.parseExpr(PREC_ADD).term) },
            .star => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "*"), left.term, self.parseExpr(PREC_MUL).term) },
            .slash => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "/"), left.term, self.parseExpr(PREC_MUL).term) },
            .percent => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "%"), left.term, self.parseExpr(PREC_MUL).term) },
            .eq_eq => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "=="), left.term, self.parseExpr(PREC_EQ).term) },
            .not_eq => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "!="), left.term, self.parseExpr(PREC_EQ).term) },
            .greater => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, ">"), left.term, self.parseExpr(PREC_CMP).term) },
            .less => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "<"), left.term, self.parseExpr(PREC_CMP).term) },
            .greater_eq => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, ">="), left.term, self.parseExpr(PREC_CMP).term) },
            .less_eq => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "<="), left.term, self.parseExpr(PREC_CMP).term) },
            .and_tok => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "&&"), left.term, self.parseExpr(PREC_AND).term) },
            .or_tok => return .{ .term = nif_make_tuple4(self.env, A.bin_op, makeBin(self.env, "||"), left.term, self.parseExpr(PREC_OR).term) },
            .question => {
                const t_node = self.parseExpr(0);
                self.eat(.colon);
                const e_node = self.parseExpr(0);
                return .{ .term = nif_make_tuple4(self.env, A.ternary, left.term, t_node.term, e_node.term) };
            },
            .dot => {
                const field_term = self.parseKeyOrField();
                var keys = [_]ERL_NIF_TERM{ A.k, A.obj, A.field };
                var vals = [_]ERL_NIF_TERM{ A.member, left.term, field_term };
                return .{ .term = makeMap(self.env, &keys, &vals) };
            },
            .lbrack => {
                const idx_node = self.parseExpr(0);
                self.eat(.rbrack);
                var keys = [_]ERL_NIF_TERM{ A.k, A.obj, A.index };
                var vals = [_]ERL_NIF_TERM{ A.index, left.term, idx_node.term };
                return .{ .term = makeMap(self.env, &keys, &vals) };
            },
            else => return left,
        }
    }

    fn parseArgs(self: *TupleExprParser) []ERL_NIF_TERM {
        var acc = Vec(ERL_NIF_TERM).init(self.arena, 8);
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rparen) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;
            const arg = self.parseExpr(0);
            self.eat(.comma);
            acc.append(arg.term);
        }
        return acc.items;
    }

    fn parseKeyOrField(self: *TupleExprParser) ERL_NIF_TERM {
        return self.parseKeyOrFieldWithSlice().term;
    }

    fn parseKeyOrFieldWithSlice(self: *TupleExprParser) struct { term: ERL_NIF_TERM, slice: []const u8 } {
        if (self.pos >= self.tokens.len) return .{ .term = makeBin(self.env, "?"), .slice = "?" };
        const tok = self.tokens[self.pos];
        self.pos += 1;
        return switch (tok.tag) {
            .ident, .type_tok, .str => .{ .term = makeBin(self.env, tok.slice), .slice = tok.slice },
            .state_var => {
                const s = if (tok.slice.len > 0 and tok.slice[0] == '$') tok.slice[1..] else tok.slice;
                return .{ .term = makeBin(self.env, s), .slice = s };
            },
            .num_int => {
                const buf = self.arena.alloc(u8, 32);
                const s = formatIntToSlice(buf, tok.int_val);
                return .{ .term = makeBin(self.env, s), .slice = s };
            },
            .num_float => {
                return .{ .term = makeBin(self.env, tok.slice), .slice = tok.slice };
            },
            else => .{ .term = makeBin(self.env, "?"), .slice = "?" },
        };
    }
};

// ── Exported NIF Functions ───────────────────────────────────────────────────

fn inspectArgBin(env: ?*ErlNifEnv, term: ERL_NIF_TERM) ?[]const u8 {
    var ptr: [*]const u8 = undefined;
    var size: usize = 0;
    if (nif_inspect_binary(env, term, &ptr, &size) == 0) return null;
    return if (size == 0) "" else ptr[0..size];
}

fn isAssignmentLine(s: []const u8) bool {
    var i: usize = 0;
    if (i < s.len and s[i] == '$') i += 1;
    if (i >= s.len or !isIdentStart(s[i])) return false;
    i += 1;
    while (i < s.len and isIdentCont(s[i])) : (i += 1) {}
    while (i < s.len and isAsciiWs(s[i])) : (i += 1) {}
    if (i < s.len and s[i] == '=') {
        if (i + 1 < s.len and s[i + 1] == '=') return false;
        return true;
    }
    return false;
}

fn makeSubOrBin(env: ?*ErlNifEnv, orig_term: ERL_NIF_TERM, orig: []const u8, sub: []const u8) ERL_NIF_TERM {
    if (sub.len == 0) return makeBin(env, "");
    const orig_start = @intFromPtr(orig.ptr);
    const orig_end = orig_start + orig.len;
    const sub_start = @intFromPtr(sub.ptr);
    if (sub_start >= orig_start and sub_start + sub.len <= orig_end) {
        if (sub_start == orig_start and sub.len == orig.len) {
            return orig_term;
        }
        return nif_make_sub_binary(env, orig_term, sub_start - orig_start, sub.len);
    }
    return makeBin(env, sub);
}

export fn zig_preprocess(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    const out = preprocessSlice(&arena, input);
    return makeSubOrBin(env, argv[0], input, out);
}

export fn zig_demux(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();

    var prose_slice: []const u8 = "";
    var code_slice: []const u8 = "";

    if (std.mem.indexOf(u8, input, "```") != null and findFence(input, 0) != null) {
        var blocks = Vec([]const u8).init(&arena, 4);
        var prose_out = Vec(u8).init(&arena, input.len);
        var pos: usize = 0;

        while (pos < input.len) {
            if (findFence(input, pos)) |fence_start| {
                if (fence_start > pos) {
                    prose_out.appendSlice(input[pos..fence_start]);
                }
                const after_open = fence_start + 3;
                if (std.mem.indexOfScalarPos(u8, input, after_open, '\n')) |nl_pos| {
                    const body_start = nl_pos + 1;
                    if (findFence(input, body_start)) |close_pos| {
                        blocks.append(input[body_start..close_pos]);
                        pos = close_pos + 3;
                    } else {
                        blocks.append(input[body_start..input.len]);
                        pos = input.len;
                    }
                } else {
                    blocks.append("");
                    pos = input.len;
                }
            } else {
                prose_out.appendSlice(input[pos..input.len]);
                break;
            }
        }

        var joined_code = Vec(u8).init(&arena, input.len);
        for (blocks.items, 0..) |b, idx| {
            if (idx > 0) joined_code.append('\n');
            joined_code.appendSlice(b);
        }
        code_slice = trimAscii(stripComments(&arena, joined_code.items));
        prose_slice = trimAscii(prose_out.items);
    } else {
        var line_start: usize = 0;
        var found_code_start: ?usize = null;
        while (line_start <= input.len) {
            const nl_opt = std.mem.indexOfScalarPos(u8, input, line_start, '\n');
            const line_end = nl_opt orelse input.len;
            const line = trimAscii(input[line_start..line_end]);
            if (isAssignmentLine(line)) {
                found_code_start = line_start;
                break;
            }
            if (nl_opt) |nl| {
                line_start = nl + 1;
            } else {
                break;
            }
        }

        if (found_code_start) |cs| {
            const prose_end = if (cs > 0 and input[cs - 1] == '\n') cs - 1 else cs;
            prose_slice = trimAscii(input[0..prose_end]);
            code_slice = trimAscii(stripComments(&arena, input[cs..input.len]));
        } else {
            prose_slice = trimAscii(input);
            code_slice = "";
        }
    }

    var keys = [_]ERL_NIF_TERM{ A.prose, A.code };
    var vals = [_]ERL_NIF_TERM{ makeBin(env, prose_slice), makeBin(env, code_slice) };
    return makeMap(env, &keys, &vals);
}

export fn zig_strip_comments(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    const out = stripComments(&arena, input);
    return makeSubOrBin(env, argv[0], input, out);
}

export fn zig_auto_close(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    const res = autoCloseSlice(&arena, input);
    const text_term = if (!res.was_incomplete) argv[0] else makeBin(env, res.text);
    const inc_term = if (res.was_incomplete) A.true_atom else A.false_atom;
    var keys = [_]ERL_NIF_TERM{ A.text, A.was_incomplete };
    var vals = [_]ERL_NIF_TERM{ text_term, inc_term };
    return makeMap(env, &keys, &vals);
}

export fn zig_tokenize(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    const tokens = tokenizeSlice(&arena, input);
    var term_arr = arena.alloc(ERL_NIF_TERM, tokens.len);
    for (tokens, 0..) |tok, i| {
        term_arr[i] = tokenToTerm(env, tok);
    }
    return makeList(env, term_arr);
}

fn parseClosedStatementsInternal(env: ?*ErlNifEnv, arena: *BumpArena, closed: []const u8, need_refs: bool) ERL_NIF_TERM {
    const tokens = tokenizeSlice(arena, closed);
    const raw_stmts = splitTokens(arena, tokens);

    if (raw_stmts.len == 0) {
        return makeList(env, &[_]ERL_NIF_TERM{});
    }

    var stmt_terms = arena.alloc(ERL_NIF_TERM, raw_stmts.len);
    for (raw_stmts, 0..) |raw, idx| {
        var parser = ExprParser.init(env, arena, raw.tokens, need_refs);
        const expr_term = parser.parseExpr(0, true);
        const state_refs_term = slicesToTermList(env, arena, parser.state_refs.items);
        const refs_term = slicesToTermList(env, arena, parser.refs.items);
        const id_term = makeBin(env, raw.id);

        if (parser.is_top_comp and std.mem.eql(u8, parser.top_comp_name, "Query")) {
            if (parser.arg1_deps.items.len > 0) {
                const deps_term = slicesToTermList(env, arena, parser.arg1_deps.items);
                const sr_pair = nif_make_tuple2(env, state_refs_term, deps_term);
                stmt_terms[idx] = nif_make_tuple5(env, A.query, id_term, expr_term, sr_pair, refs_term);
            } else {
                stmt_terms[idx] = nif_make_tuple5(env, A.query, id_term, expr_term, state_refs_term, refs_term);
            }
        } else if (parser.is_top_comp and std.mem.eql(u8, parser.top_comp_name, "Mutation")) {
            stmt_terms[idx] = nif_make_tuple5(env, A.mutation, id_term, expr_term, state_refs_term, refs_term);
        } else if (raw.id_tag == .state_var) {
            stmt_terms[idx] = nif_make_tuple5(env, A.state, id_term, expr_term, state_refs_term, refs_term);
        } else {
            stmt_terms[idx] = nif_make_tuple5(env, A.value, id_term, expr_term, state_refs_term, refs_term);
        }
    }

    return makeList(env, stmt_terms);
}

export fn zig_parse_statements(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 2) return nif_make_badarg(env);
    const closed = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var need_refs_int: c_int = 0;
    _ = nif_get_int(env, argv[1], &need_refs_int);
    const need_refs = (need_refs_int != 0);

    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    return parseClosedStatementsInternal(env, &arena, closed, need_refs);
}

export fn zig_parse_source(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 2) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var need_refs_int: c_int = 0;
    _ = nif_get_int(env, argv[1], &need_refs_int);
    const need_refs = (need_refs_int != 0);

    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();

    const trimmed = preprocessSlice(&arena, input);
    if (trimmed.len == 0) {
        return A.empty;
    }

    const ac = autoCloseSlice(&arena, trimmed);
    const stmts_term = parseClosedStatementsInternal(env, &arena, ac.text, need_refs);
    const inc_term = if (ac.was_incomplete) A.true_atom else A.false_atom;
    return nif_make_tuple2(env, inc_term, stmts_term);
}

export fn zig_parse_pending(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 2) return nif_make_badarg(env);
    const pending = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var need_refs_int: c_int = 0;
    _ = nif_get_int(env, argv[1], &need_refs_int);
    const need_refs = (need_refs_int != 0);

    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();

    const ac = autoCloseSlice(&arena, pending);
    const stmts_term = parseClosedStatementsInternal(env, &arena, ac.text, need_refs);
    const inc_term = if (ac.was_incomplete) A.true_atom else A.false_atom;
    return nif_make_tuple2(env, inc_term, stmts_term);
}

export fn zig_parse_symbols(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    const trimmed = preprocessSlice(&arena, input);
    if (trimmed.len == 0) {
        return makeMap(env, &[_]ERL_NIF_TERM{}, &[_]ERL_NIF_TERM{});
    }
    const closed = autoCloseSlice(&arena, trimmed);
    const tokens = tokenizeSlice(&arena, closed.text);
    const raw_stmts = splitTokens(&arena, tokens);
    if (raw_stmts.len == 0) {
        return makeMap(env, &[_]ERL_NIF_TERM{}, &[_]ERL_NIF_TERM{});
    }

    var keys = Vec(ERL_NIF_TERM).init(&arena, raw_stmts.len);
    var vals = Vec(ERL_NIF_TERM).init(&arena, raw_stmts.len);
    var id_slices = Vec([]const u8).init(&arena, raw_stmts.len);

    for (raw_stmts) |raw| {
        var tparser = TupleExprParser{
            .env = env,
            .arena = &arena,
            .tokens = raw.tokens,
        };
        const val_node = tparser.parseExpr(0);

        // Deduplicate keys (last definition wins, required by enif_make_map_from_arrays!)
        var found_idx: ?usize = null;
        for (id_slices.items, 0..) |existing_id, i| {
            if (std.mem.eql(u8, existing_id, raw.id)) {
                found_idx = i;
                break;
            }
        }
        if (found_idx) |fi| {
            vals.items[fi] = val_node.term;
        } else {
            id_slices.append(raw.id);
            keys.append(makeBin(env, raw.id));
            vals.append(val_node.term);
        }
    }

    return makeMap(env, keys.items, vals.items);
}

// ── Merge Statements Fast Scanner (Zero AST Map Allocation!) ─────────────────

fn splitStatementSource(arena: *BumpArena, input: []const u8) [][]const u8 {
    var slices = Vec([]const u8).init(arena, 32);
    var i: usize = 0;
    var start: usize = 0;
    var depth: i32 = 0;
    var in_str: u8 = 0;

    while (i < input.len) {
        const c = input[i];
        if (in_str != 0) {
            if (c == '\\' and i + 1 < input.len) {
                i += 2;
            } else if (c == in_str) {
                in_str = 0;
                i += 1;
            } else {
                i += 1;
            }
        } else {
            switch (c) {
                '"', '\'' => {
                    in_str = c;
                    i += 1;
                },
                '(', '[', '{' => {
                    depth += 1;
                    i += 1;
                },
                ')', ']', '}' => {
                    if (depth > 0) depth -= 1;
                    i += 1;
                },
                '\n' => {
                    if (depth <= 0) {
                        const stmt = trimAscii(input[start..i]);
                        if (stmt.len > 0) slices.append(stmt);
                        start = i + 1;
                    }
                    i += 1;
                },
                else => i += 1,
            }
        }
    }

    const tail = trimAscii(input[start..input.len]);
    if (tail.len > 0) slices.append(tail);
    return slices.items;
}

const MetaNodeKind = enum(u8) {
    null_node,
    ref_node,
    other_node,
};

const MetaNode = struct {
    kind: MetaNodeKind,
    ref_name: []const u8 = "",
};

const MetaExprScanner = struct {
    tokens: []const ZigToken,
    pos: usize = 0,
    refs: Vec([]const u8),

    inline fn recordRef(self: *MetaExprScanner, name: []const u8) void {
        addUniqueRef(&self.refs, name);
    }

    inline fn eat(self: *MetaExprScanner, tag: TokenTag) void {
        if (self.pos < self.tokens.len and self.tokens[self.pos].tag == tag) {
            self.pos += 1;
        }
    }

    pub fn scanExpr(self: *MetaExprScanner, min_prec: u8) MetaNode {
        var left = self.scanPrefix();
        while (self.pos < self.tokens.len) {
            const prec = infixPrec(self.tokens[self.pos].tag);
            if (prec > min_prec) {
                left = self.scanInfix();
            } else {
                break;
            }
        }
        return left;
    }

    fn scanPrefix(self: *MetaExprScanner) MetaNode {
        if (self.pos >= self.tokens.len) return .{ .kind = .null_node };
        const tok = self.tokens[self.pos];
        switch (tok.tag) {
            .str, .num_int, .num_float, .true_tok, .false_tok => {
                self.pos += 1;
                return .{ .kind = .other_node };
            },
            .null_tok => {
                self.pos += 1;
                return .{ .kind = .null_node };
            },
            .lbrack => {
                self.pos += 1;
                while (self.pos < self.tokens.len) {
                    const t = self.tokens[self.pos].tag;
                    if (t == .rbrack) {
                        self.pos += 1;
                        break;
                    }
                    if (t == .eof) break;
                    _ = self.scanExpr(0);
                    self.eat(.comma);
                }
                return .{ .kind = .other_node };
            },
            .lbrace => {
                self.pos += 1;
                while (self.pos < self.tokens.len) {
                    const t = self.tokens[self.pos].tag;
                    if (t == .rbrace) {
                        self.pos += 1;
                        break;
                    }
                    if (t == .eof) break;
                    if (self.pos < self.tokens.len) self.pos += 1;
                    self.eat(.colon);
                    _ = self.scanExpr(0);
                    self.eat(.comma);
                }
                return .{ .kind = .other_node };
            },
            .state_var => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .equals) {
                    self.pos += 2;
                    _ = self.scanExpr(0);
                    return .{ .kind = .other_node };
                } else {
                    self.pos += 1;
                    return .{ .kind = .other_node };
                }
            },
            .type_tok => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    if (!isBuiltin(tok.slice) or std.mem.eql(u8, tok.slice, "Action")) {
                        self.pos += 2;
                        self.scanArgs();
                        return .{ .kind = .other_node };
                    } else {
                        self.pos += 1;
                        self.recordRef(tok.slice);
                        return .{ .kind = .ref_node, .ref_name = tok.slice };
                    }
                } else {
                    self.pos += 1;
                    self.recordRef(tok.slice);
                    return .{ .kind = .ref_node, .ref_name = tok.slice };
                }
            },
            .builtin_call => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    self.pos += 2;
                    self.scanArgs();
                    return .{ .kind = .other_node };
                } else {
                    self.pos += 1;
                    self.recordRef(tok.slice);
                    return .{ .kind = .ref_node, .ref_name = tok.slice };
                }
            },
            .ident => {
                self.pos += 1;
                self.recordRef(tok.slice);
                return .{ .kind = .ref_node, .ref_name = tok.slice };
            },
            .not_tok, .minus => {
                self.pos += 1;
                _ = self.scanExpr(PREC_UNARY);
                return .{ .kind = .other_node };
            },
            .lparen => {
                self.pos += 1;
                const inner = self.scanExpr(0);
                self.eat(.rparen);
                return inner;
            },
            else => {
                self.pos += 1;
                return .{ .kind = .null_node };
            },
        }
    }

    fn scanInfix(self: *MetaExprScanner) MetaNode {
        const tok = self.tokens[self.pos];
        self.pos += 1;
        switch (tok.tag) {
            .plus, .minus => _ = self.scanExpr(PREC_ADD),
            .star, .slash, .percent => _ = self.scanExpr(PREC_MUL),
            .eq_eq, .not_eq => _ = self.scanExpr(PREC_EQ),
            .greater, .less, .greater_eq, .less_eq => _ = self.scanExpr(PREC_CMP),
            .and_tok => _ = self.scanExpr(PREC_AND),
            .or_tok => _ = self.scanExpr(PREC_OR),
            .question => {
                _ = self.scanExpr(0);
                self.eat(.colon);
                _ = self.scanExpr(0);
            },
            .dot => {
                if (self.pos < self.tokens.len) self.pos += 1;
            },
            .lbrack => {
                _ = self.scanExpr(0);
                self.eat(.rbrack);
            },
            else => {},
        }
        return .{ .kind = .other_node };
    }

    fn scanArgs(self: *MetaExprScanner) void {
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rparen) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;
            _ = self.scanExpr(0);
            self.eat(.comma);
        }
    }
};

export fn zig_parse_merge_statements(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 2) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var strip_fences_int: c_int = 0;
    _ = nif_get_int(env, argv[1], &strip_fences_int);

    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();
    const unfenced = if (strip_fences_int != 0) stripFences(&arena, input) else input;
    const trimmed = trimAscii(stripComments(&arena, unfenced));
    if (trimmed.len == 0) {
        return makeList(env, &[_]ERL_NIF_TERM{});
    }

    const closed = autoCloseSlice(&arena, trimmed).text;
    const raw_slices = splitStatementSource(&arena, closed);
    const tokens = tokenizeSlice(&arena, closed);
    const raw_stmts = splitTokens(&arena, tokens);

    const count = @min(raw_slices.len, raw_stmts.len);
    if (count == 0) {
        return makeList(env, &[_]ERL_NIF_TERM{});
    }

    var out_terms = arena.alloc(ERL_NIF_TERM, count);
    for (0..count) |idx| {
        const raw_src = raw_slices[idx];
        const stmt = raw_stmts[idx];
        var scanner = MetaExprScanner{
            .tokens = stmt.tokens,
            .refs = Vec([]const u8).init(&arena, 8),
        };
        const root_meta = scanner.scanExpr(0);
        const is_null = (root_meta.kind == .null_node);
        const is_stream_or_bind = (root_meta.kind == .ref_node) and
            (std.mem.eql(u8, root_meta.ref_name, "StreamSource") or std.mem.eql(u8, root_meta.ref_name, "Bind"));

        out_terms[idx] = nif_make_tuple5(
            env,
            makeBin(env, stmt.id),
            makeBin(env, raw_src),
            if (is_null) A.true_atom else A.false_atom,
            if (is_stream_or_bind) A.true_atom else A.false_atom,
            slicesToTermList(env, &arena, scanner.refs.items),
        );
    }

    return makeList(env, out_terms);
}

