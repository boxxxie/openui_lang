const std = @import("std");

pub const ErlNifEnv = opaque {};
pub const ErlNifResourceType = opaque {};
pub const ERL_NIF_TERM = usize;

extern fn nif_inspect_binary(env: ?*ErlNifEnv, term: ERL_NIF_TERM, data_out: *[*]const u8, size_out: *usize) c_int;
extern fn nif_get_int(env: ?*ErlNifEnv, term: ERL_NIF_TERM, val_out: *c_int) c_int;
extern fn nif_get_uint(env: ?*ErlNifEnv, term: ERL_NIF_TERM, val_out: *c_uint) c_int;
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
extern fn nif_make_new_map(env: ?*ErlNifEnv) ERL_NIF_TERM;
extern fn nif_get_map_value(env: ?*ErlNifEnv, map: ERL_NIF_TERM, key: ERL_NIF_TERM, val_out: *ERL_NIF_TERM) c_int;
extern fn nif_make_map_put(env: ?*ErlNifEnv, map_in: ERL_NIF_TERM, key: ERL_NIF_TERM, val: ERL_NIF_TERM, map_out: *ERL_NIF_TERM) c_int;
extern fn nif_make_map_remove(env: ?*ErlNifEnv, map_in: ERL_NIF_TERM, key: ERL_NIF_TERM, map_out: *ERL_NIF_TERM) c_int;
extern fn nif_open_resource_type(env: ?*ErlNifEnv, name: [*:0]const u8, dtor: ?*const fn (?*ErlNifEnv, ?*anyopaque) callconv(.c) void) ?*ErlNifResourceType;
extern fn nif_alloc_resource(res_type: ?*ErlNifResourceType, size: usize) ?*anyopaque;
extern fn nif_make_resource(env: ?*ErlNifEnv, obj: ?*anyopaque) ERL_NIF_TERM;
extern fn nif_release_resource(obj: ?*anyopaque) void;
extern fn nif_get_resource(env: ?*ErlNifEnv, term: ERL_NIF_TERM, res_type: ?*ErlNifResourceType, obj_out: *?*anyopaque) c_int;
extern fn nif_make_badarg(env: ?*ErlNifEnv) ERL_NIF_TERM;
extern fn nif_alloc(size: usize) ?[*]u8;
extern fn nif_free(ptr: ?[*]u8) void;
extern fn nif_parse_double(ptr: [*]const u8, len: usize) f64;
extern fn nif_format_double(val: f64, buf: [*]u8, buf_size: usize) usize;

var STREAM_RESOURCE_TYPE: ?*ErlNifResourceType = null;

// Pre-cached BEAM atoms (populated in zig_nif_load)
const Atoms = struct {
    ok: ERL_NIF_TERM = 0,
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
    runtime_ref: ERL_NIF_TERM = 0,
    ref_type: ERL_NIF_TERM = 0,
    mapped_props: ERL_NIF_TERM = 0,
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

    // Materialize / ParseResult / ElementNode / Error keys
    root: ERL_NIF_TERM = 0,
    root_expression: ERL_NIF_TERM = 0,
    meta: ERL_NIF_TERM = 0,
    incomplete: ERL_NIF_TERM = 0,
    orphaned: ERL_NIF_TERM = 0,
    statement_count: ERL_NIF_TERM = 0,
    errors: ERL_NIF_TERM = 0,
    state_declarations: ERL_NIF_TERM = 0,
    query_statements: ERL_NIF_TERM = 0,
    mutation_statements: ERL_NIF_TERM = 0,
    type_name: ERL_NIF_TERM = 0,
    props: ERL_NIF_TERM = 0,
    partial: ERL_NIF_TERM = 0,
    has_dynamic_props: ERL_NIF_TERM = 0,
    statement_id: ERL_NIF_TERM = 0,
    component: ERL_NIF_TERM = 0,
    path: ERL_NIF_TERM = 0,
    message: ERL_NIF_TERM = 0,
    severity: ERL_NIF_TERM = 0,
    tool_ast: ERL_NIF_TERM = 0,
    args_ast: ERL_NIF_TERM = 0,
    defaults_ast: ERL_NIF_TERM = 0,
    refresh_ast: ERL_NIF_TERM = 0,
    complete: ERL_NIF_TERM = 0,
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

    STREAM_RESOURCE_TYPE = nif_open_resource_type(env, "OpenUIStreamResource", streamResourceDtor);
    if (STREAM_RESOURCE_TYPE == null) return -1;

    A.ok = makeAtom(env, "ok");
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
    A.runtime_ref = makeAtom(env, "runtime_ref");
    A.ref_type = makeAtom(env, "ref_type");
    A.mapped_props = makeAtom(env, "mapped_props");
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

    A.root = makeAtom(env, "root");
    A.root_expression = makeAtom(env, "root_expression");
    A.meta = makeAtom(env, "meta");
    A.incomplete = makeAtom(env, "incomplete");
    A.orphaned = makeAtom(env, "orphaned");
    A.statement_count = makeAtom(env, "statement_count");
    A.errors = makeAtom(env, "errors");
    A.state_declarations = makeAtom(env, "state_declarations");
    A.query_statements = makeAtom(env, "query_statements");
    A.mutation_statements = makeAtom(env, "mutation_statements");
    A.type_name = makeAtom(env, "type_name");
    A.props = makeAtom(env, "props");
    A.partial = makeAtom(env, "partial");
    A.has_dynamic_props = makeAtom(env, "has_dynamic_props");
    A.statement_id = makeAtom(env, "statement_id");
    A.component = makeAtom(env, "component");
    A.path = makeAtom(env, "path");
    A.message = makeAtom(env, "message");
    A.severity = makeAtom(env, "severity");
    A.tool_ast = makeAtom(env, "tool_ast");
    A.args_ast = makeAtom(env, "args_ast");
    A.defaults_ast = makeAtom(env, "defaults_ast");
    A.refresh_ast = makeAtom(env, "refresh_ast");
    A.complete = makeAtom(env, "complete");

    return 0;
}

// ── Stack-First + ERTS Slab Bump Arena (Zero TLS!) ───────────────────────────

const BumpArena = struct {
    buf: []u8,
    pos: usize = 0,
    heap_slabs: [64]?[*]u8 = [_]?[*]u8{null} ** 64,
    slab_count: usize = 0,

    pub fn init(stack_buf: []u8) BumpArena {
        return .{ .buf = stack_buf, .pos = 0 };
    }

    pub fn deinit(self: *BumpArena) void {
        for (0..self.slab_count) |i| {
            nif_free(self.heap_slabs[i]);
            self.heap_slabs[i] = null;
        }
        self.slab_count = 0;
        self.buf = &[_]u8{};
        self.pos = 0;
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

    pub fn dupe(self: *BumpArena, comptime T: type, slice: []const T) []T {
        if (slice.len == 0) return &[_]T{};
        const dst = self.alloc(T, slice.len);
        @memcpy(dst, slice);
        return dst;
    }

    pub fn create(self: *BumpArena, comptime T: type, val: T) *T {
        const dst = self.alloc(T, 1);
        dst[0] = val;
        return &dst[0];
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

fn hasUnquotedComment(input: []const u8) bool {
    var in_str: u8 = 0;
    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];
        if (in_str != 0) {
            if (c == '\\' and i + 1 < input.len) {
                i += 2;
            } else {
                if (c == in_str) in_str = 0;
                i += 1;
            }
        } else {
            if (c == '"' or c == '\'') {
                in_str = c;
                i += 1;
            } else if (c == '#') {
                return true;
            } else if (c == '/' and i + 1 < input.len and input[i + 1] == '/') {
                return true;
            } else {
                i += 1;
            }
        }
    }
    return false;
}

fn stripComments(arena: *BumpArena, input: []const u8) []const u8 {
    // Fast check: if neither '#' nor '//' appears outside quotes, return input unchanged!
    if (std.mem.indexOfScalar(u8, input, '#') == null and std.mem.indexOf(u8, input, "//") == null) {
        return input;
    }
    if (!hasUnquotedComment(input)) {
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

// ── Feature 2: Native Schema Registry & Binary Decoder ───────────────────────

inline fn fnv1a32(s: []const u8) u32 {
    var h: u32 = 2166136261;
    for (s) |b| {
        h ^= b;
        h *%= 16777619;
    }
    return h;
}

const ZigDefaultEntry = struct {
    key: []const u8,
    val: ZigDefaultVal,
};

const ZigDefaultVal = union(enum) {
    null_val,
    bool_val: bool,
    int_val: i64,
    float_val: f64,
    str_val: []const u8,
    arr_val: []ZigDefaultVal,
    obj_val: []ZigDefaultEntry,
};

const SchemaKind = enum(u8) {
    composite = 0,
    object = 1,
    array = 2,
    leaf = 3,
};

const ReqFieldSpec = struct {
    name: []const u8,
    has_default: bool,
    default_val: ZigDefaultVal,
};

const ObjPropSpec = struct {
    name: []const u8,
    required: bool,
    has_default: bool,
    default_val: ZigDefaultVal,
    has_schema: bool,
    schema: SchemaNode,
};

const SchemaNode = struct {
    elem_reject_expected: []const u8 = "",
    kind: SchemaKind = .leaf,
    // .composite
    only_component_slot: bool = false,
    slot_expected: []const u8 = "",
    // .object
    required: []ReqFieldSpec = &[_]ReqFieldSpec{},
    props: []ObjPropSpec = &[_]ObjPropSpec{},
    // .array
    has_items: bool = false,
    items: ?*SchemaNode = null,
    // .leaf
    leaf_kind: u8 = 0, // 0=any, 1=string, 2=number, 3=boolean, 4=enum
    enum_expected: []const u8 = "",
    enum_vals: []ZigDefaultVal = &[_]ZigDefaultVal{},
};

const ParamDef = struct {
    name: []const u8,
    path: []const u8,
    required: bool,
    has_default: bool,
    default_val: ZigDefaultVal,
    has_schema: bool,
    schema: SchemaNode,
};

const CompDef = struct {
    name: []const u8,
    name_hash: u32,
    signature: []const u8,
    params: []ParamDef,
};

const CallDef = struct {
    name: []const u8,
    name_hash: u32,
    is_action: bool,
    is_builtin: bool,
    is_lazy: bool,
    signature: []const u8,
    params: []ParamDef,
};

const ZigSchema = struct {
    schema_id: u32,
    arena: BumpArena,
    root: []const u8,
    avail_suffix: []const u8,
    components: []CompDef,
    call_defs: []CallDef,

    pub inline fn findComponent(self: *const ZigSchema, hash: u32, name: []const u8) ?*const CompDef {
        for (self.components) |*c| {
            if (c.name_hash == hash and std.mem.eql(u8, c.name, name)) return c;
        }
        return null;
    }

    pub inline fn findCallDef(self: *const ZigSchema, hash: u32, name: []const u8) ?*const CallDef {
        for (self.call_defs) |*f| {
            if (f.name_hash == hash and std.mem.eql(u8, f.name, name)) return f;
        }
        return null;
    }
};

const BinaryReader = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn readU8(self: *BinaryReader) u8 {
        if (self.pos >= self.data.len) return 0;
        const b = self.data[self.pos];
        self.pos += 1;
        return b;
    }

    pub fn readU32(self: *BinaryReader) u32 {
        if (self.pos + 4 > self.data.len) {
            self.pos = self.data.len;
            return 0;
        }
        const v = std.mem.readInt(u32, self.data[self.pos..][0..4], .little);
        self.pos += 4;
        return v;
    }

    pub fn readI64(self: *BinaryReader) i64 {
        if (self.pos + 8 > self.data.len) {
            self.pos = self.data.len;
            return 0;
        }
        const v = std.mem.readInt(i64, self.data[self.pos..][0..8], .little);
        self.pos += 8;
        return v;
    }

    pub fn readF64(self: *BinaryReader) f64 {
        if (self.pos + 8 > self.data.len) {
            self.pos = self.data.len;
            return 0.0;
        }
        const bits = std.mem.readInt(u64, self.data[self.pos..][0..8], .little);
        self.pos += 8;
        return @bitCast(bits);
    }

    pub fn readStr(self: *BinaryReader, arena: *BumpArena) []const u8 {
        const len: usize = @intCast(self.readU32());
        if (len == 0 or self.pos + len > self.data.len) {
            self.pos = @min(self.data.len, self.pos + len);
            return "";
        }
        const slice = arena.dupe(u8, self.data[self.pos .. self.pos + len]);
        self.pos += len;
        return slice;
    }

    pub fn readDefaultVal(self: *BinaryReader, arena: *BumpArena) ZigDefaultVal {
        const tag = self.readU8();
        return switch (tag) {
            0 => .null_val,
            1 => .{ .bool_val = (self.readU8() != 0) },
            2 => .{ .int_val = self.readI64() },
            3 => .{ .float_val = self.readF64() },
            4 => .{ .str_val = self.readStr(arena) },
            5 => {
                const count: usize = @intCast(self.readU32());
                var items = arena.alloc(ZigDefaultVal, count);
                for (0..count) |i| {
                    items[i] = self.readDefaultVal(arena);
                }
                return .{ .arr_val = items };
            },
            6 => {
                const count: usize = @intCast(self.readU32());
                var entries = arena.alloc(ZigDefaultEntry, count);
                for (0..count) |i| {
                    const k = self.readStr(arena);
                    const v = self.readDefaultVal(arena);
                    entries[i] = .{ .key = k, .val = v };
                }
                return .{ .obj_val = entries };
            },
            else => .null_val,
        };
    }

    pub fn readSchemaNode(self: *BinaryReader, arena: *BumpArena) SchemaNode {
        const elem_reject = self.readStr(arena);
        const kind_byte = self.readU8();
        var node = SchemaNode{
            .elem_reject_expected = elem_reject,
            .kind = switch (kind_byte) {
                0 => .composite,
                1 => .object,
                2 => .array,
                else => .leaf,
            },
        };

        switch (node.kind) {
            .composite => {
                node.only_component_slot = (self.readU8() != 0);
                node.slot_expected = self.readStr(arena);
            },
            .object => {
                const req_count: usize = @intCast(self.readU32());
                var reqs = arena.alloc(ReqFieldSpec, req_count);
                for (0..req_count) |i| {
                    const rname = self.readStr(arena);
                    const has_def = (self.readU8() != 0);
                    const dval = if (has_def) self.readDefaultVal(arena) else ZigDefaultVal.null_val;
                    reqs[i] = .{ .name = rname, .has_default = has_def, .default_val = dval };
                }
                node.required = reqs;

                const prop_count: usize = @intCast(self.readU32());
                var props = arena.alloc(ObjPropSpec, prop_count);
                for (0..prop_count) |i| {
                    const pname = self.readStr(arena);
                    const preq = (self.readU8() != 0);
                    const has_def = (self.readU8() != 0);
                    const dval = if (has_def) self.readDefaultVal(arena) else ZigDefaultVal.null_val;
                    const has_sc = (self.readU8() != 0);
                    const sc = if (has_sc) self.readSchemaNode(arena) else SchemaNode{};
                    props[i] = .{
                        .name = pname,
                        .required = preq,
                        .has_default = has_def,
                        .default_val = dval,
                        .has_schema = has_sc,
                        .schema = sc,
                    };
                }
                node.props = props;
            },
            .array => {
                const has_items = (self.readU8() != 0);
                node.has_items = has_items;
                if (has_items) {
                    const sub = self.readSchemaNode(arena);
                    node.items = arena.create(SchemaNode, sub);
                }
            },
            .leaf => {
                const lkind = self.readU8();
                node.leaf_kind = lkind;
                if (lkind == 4) {
                    node.enum_expected = self.readStr(arena);
                    const ev_count: usize = @intCast(self.readU32());
                    var evals = arena.alloc(ZigDefaultVal, ev_count);
                    for (0..ev_count) |i| {
                        evals[i] = self.readDefaultVal(arena);
                    }
                    node.enum_vals = evals;
                }
            },
        }

        return node;
    }

    pub fn readParam(self: *BinaryReader, arena: *BumpArena) ParamDef {
        const name = self.readStr(arena);
        const path = self.readStr(arena);
        const req = (self.readU8() != 0);
        const has_def = (self.readU8() != 0);
        const dval = if (has_def) self.readDefaultVal(arena) else ZigDefaultVal.null_val;
        const has_sc = (self.readU8() != 0);
        const sc = if (has_sc) self.readSchemaNode(arena) else SchemaNode{};
        return .{
            .name = name,
            .path = path,
            .required = req,
            .has_default = has_def,
            .default_val = dval,
            .has_schema = has_sc,
            .schema = sc,
        };
    }
};

fn decodeSchema(schema_id: u32, bin: []const u8) *ZigSchema {
    const raw_mem = nif_alloc(@sizeOf(ZigSchema)) orelse @panic("OpenUILang.ZigNIF: out of memory");
    const schema_ptr: *ZigSchema = @ptrCast(@alignCast(raw_mem));
    schema_ptr.* = .{
        .schema_id = schema_id,
        .arena = BumpArena.init(&[_]u8{}),
        .root = "",
        .avail_suffix = "",
        .components = &[_]CompDef{},
        .call_defs = &[_]CallDef{},
    };

    var reader = BinaryReader{ .data = bin };
    const arena = &schema_ptr.arena;

    schema_ptr.root = reader.readStr(arena);
    schema_ptr.avail_suffix = reader.readStr(arena);

    const comp_count: usize = @intCast(reader.readU32());
    var comps = arena.alloc(CompDef, comp_count);
    for (0..comp_count) |i| {
        const cname = reader.readStr(arena);
        const csig = reader.readStr(arena);
        const pcount: usize = @intCast(reader.readU32());
        var params = arena.alloc(ParamDef, pcount);
        for (0..pcount) |pi| {
            params[pi] = reader.readParam(arena);
        }
        comps[i] = .{
            .name = cname,
            .name_hash = fnv1a32(cname),
            .signature = csig,
            .params = params,
        };
    }
    schema_ptr.components = comps;

    const call_count: usize = @intCast(reader.readU32());
    var calls = arena.alloc(CallDef, call_count);
    for (0..call_count) |i| {
        const fname = reader.readStr(arena);
        const is_act = (reader.readU8() != 0);
        const is_builtin = (reader.readU8() != 0);
        const is_lazy = (reader.readU8() != 0);
        const fsig = reader.readStr(arena);
        const pcount: usize = @intCast(reader.readU32());
        var params = arena.alloc(ParamDef, pcount);
        for (0..pcount) |pi| {
            params[pi] = reader.readParam(arena);
        }
        calls[i] = .{
            .name = fname,
            .name_hash = fnv1a32(fname),
            .is_action = is_act,
            .is_builtin = is_builtin,
            .is_lazy = is_lazy,
            .signature = fsig,
            .params = params,
        };
    }
    schema_ptr.call_defs = calls;

    return schema_ptr;
}

var SCHEMA_REGISTRY: [64]?*ZigSchema = [_]?*ZigSchema{null} ** 64;
var SCHEMA_COUNT: usize = 0;
var SCHEMA_LOCK = std.atomic.Value(u32).init(0);

inline fn acquireSchemaLock() void {
    while (SCHEMA_LOCK.cmpxchgWeak(0, 1, .acquire, .monotonic) != null) {
        std.atomic.spinLoopHint();
    }
}

inline fn releaseSchemaLock() void {
    SCHEMA_LOCK.store(0, .release);
}

fn getOrDecodeSchema(schema_id: u32, schema_bin: []const u8) *const ZigSchema {
    acquireSchemaLock();
    defer releaseSchemaLock();

    for (0..SCHEMA_COUNT) |i| {
        if (SCHEMA_REGISTRY[i]) |s| {
            if (s.schema_id == schema_id) return s;
        }
    }

    const decoded = decodeSchema(schema_id, schema_bin);
    if (SCHEMA_COUNT < SCHEMA_REGISTRY.len) {
        SCHEMA_REGISTRY[SCHEMA_COUNT] = decoded;
        SCHEMA_COUNT += 1;
    } else {
        SCHEMA_REGISTRY[schema_id % SCHEMA_REGISTRY.len] = decoded;
    }
    return decoded;
}

export fn zig_register_schema(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 2) return nif_make_badarg(env);
    var schema_id: c_uint = 0;
    if (nif_get_uint(env, argv[0], &schema_id) == 0) return nif_make_badarg(env);
    const bin = inspectArgBin(env, argv[1]) orelse return nif_make_badarg(env);
    _ = getOrDecodeSchema(@intCast(schema_id), bin);
    return A.ok;
}

// ── Native AST & Pratt Parser (Zero BEAM Allocation) ─────────────────────────

const AstKind = enum(u8) {
    str,
    num_int,
    num_float,
    bool_node,
    null_node,
    ph,
    ref,
    state_ref,
    runtime_ref,
    comp,
    arr,
    obj,
    bin_op,
    unary_op,
    ternary,
    member,
    index,
    assign,
};

const ZigAstObjEntry = struct {
    key: []const u8,
    val: *ZigAstNode,
};

const ZigMappedProp = struct {
    key: []const u8,
    val: *ZigAstNode,
};

const ZigAstNode = struct {
    kind: AstKind,
    has_ref_or_comp: bool = false,
    is_fn: bool = false,
    bool_val: bool = false,
    int_val: i64 = 0,
    float_val: f64 = 0.0,
    str_val: []const u8 = "",
    args: []*ZigAstNode = &[_]*ZigAstNode{},
    obj_entries: []ZigAstObjEntry = &[_]ZigAstObjEntry{},
    mapped_props: ?[]ZigMappedProp = null,
    left: ?*ZigAstNode = null,
    right: ?*ZigAstNode = null,
    third: ?*ZigAstNode = null,
};

const StmtKind = enum(u8) {
    value,
    state,
    query,
    mutation,
};

const NativeParsedStmt = struct {
    id: []const u8,
    id_hash: u32,
    kind: StmtKind,
    expr: *ZigAstNode,
    state_refs: [][]const u8,
    refs: [][]const u8,
    deps: [][]const u8,
};

inline fn isReservedCall(name: []const u8) bool {
    return std.mem.eql(u8, name, "Query") or std.mem.eql(u8, name, "Mutation");
}

inline fn isComponentCallNode(node: *const ZigAstNode) bool {
    return node.kind == .comp and !node.is_fn and !isBuiltin(node.str_val) and !isReservedCall(node.str_val);
}

fn containsComponentAst(node: *const ZigAstNode) bool {
    if (isComponentCallNode(node)) return true;
    return switch (node.kind) {
        .comp => {
            for (node.args) |a| {
                if (containsComponentAst(a)) return true;
            }
            if (node.mapped_props) |mp| {
                for (mp) |p| {
                    if (containsComponentAst(p.val)) return true;
                }
            }
            return false;
        },
        .arr => {
            for (node.args) |e| {
                if (containsComponentAst(e)) return true;
            }
            return false;
        },
        .obj => {
            for (node.obj_entries) |e| {
                if (containsComponentAst(e.val)) return true;
            }
            return false;
        },
        .bin_op, .index => {
            if (node.left) |l| if (containsComponentAst(l)) return true;
            if (node.right) |r| if (containsComponentAst(r)) return true;
            return false;
        },
        .unary_op, .member, .assign => {
            if (node.left) |l| if (containsComponentAst(l)) return true;
            return false;
        },
        .ternary => {
            if (node.left) |c| if (containsComponentAst(c)) return true;
            if (node.right) |t| if (containsComponentAst(t)) return true;
            if (node.third) |e| if (containsComponentAst(e)) return true;
            return false;
        },
        else => false,
    };
}

const NativeExprParser = struct {
    arena: *BumpArena,
    tokens: []const ZigToken,
    pos: usize = 0,
    need_refs: bool,
    refs: Vec([]const u8),
    state_refs: Vec([]const u8),
    in_arg1: bool = false,
    arg1_deps: Vec([]const u8),
    top_comp_name: []const u8 = "",
    is_top_comp: bool = false,

    pub fn init(arena: *BumpArena, tokens: []const ZigToken, need_refs: bool) NativeExprParser {
        return .{
            .arena = arena,
            .tokens = tokens,
            .need_refs = need_refs,
            .refs = Vec([]const u8).init(arena, if (need_refs) 8 else 0),
            .state_refs = Vec([]const u8).init(arena, 8),
            .arg1_deps = Vec([]const u8).init(arena, 4),
        };
    }

    inline fn recordRef(self: *NativeExprParser, name: []const u8) void {
        if (self.need_refs) addUniqueRef(&self.refs, name);
    }

    inline fn recordStateRef(self: *NativeExprParser, name: []const u8) void {
        addUniqueRef(&self.state_refs, name);
        if (self.in_arg1) addUniqueRef(&self.arg1_deps, name);
    }

    inline fn eat(self: *NativeExprParser, tag: TokenTag) void {
        if (self.pos < self.tokens.len and self.tokens[self.pos].tag == tag) {
            self.pos += 1;
        }
    }

    pub fn parseExpr(self: *NativeExprParser, min_prec: u8, at_root: bool) *ZigAstNode {
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

    fn parsePrefix(self: *NativeExprParser, at_root: bool) *ZigAstNode {
        if (self.pos >= self.tokens.len) {
            return self.arena.create(ZigAstNode, .{ .kind = .null_node });
        }

        const tok = self.tokens[self.pos];
        switch (tok.tag) {
            .str => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .str, .str_val = tok.slice });
            },
            .num_int => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .num_int, .int_val = tok.int_val });
            },
            .num_float => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .num_float, .float_val = tok.float_val });
            },
            .true_tok => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .bool_node, .bool_val = true });
            },
            .false_tok => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .bool_node, .bool_val = false });
            },
            .null_tok => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .null_node });
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
                    return self.arena.create(ZigAstNode, .{
                        .kind = .assign,
                        .has_ref_or_comp = val.has_ref_or_comp,
                        .str_val = tok.slice,
                        .left = val,
                    });
                } else {
                    self.pos += 1;
                    self.recordStateRef(tok.slice);
                    return self.arena.create(ZigAstNode, .{ .kind = .state_ref, .str_val = tok.slice });
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
                        return self.arena.create(ZigAstNode, .{
                            .kind = .comp,
                            .has_ref_or_comp = true,
                            .is_fn = false,
                            .str_val = tok.slice,
                            .args = args_slice,
                        });
                    } else {
                        self.pos += 1;
                        self.recordRef(tok.slice);
                        return self.arena.create(ZigAstNode, .{ .kind = .ref, .has_ref_or_comp = true, .str_val = tok.slice });
                    }
                } else {
                    self.pos += 1;
                    self.recordRef(tok.slice);
                    return self.arena.create(ZigAstNode, .{ .kind = .ref, .has_ref_or_comp = true, .str_val = tok.slice });
                }
            },
            .builtin_call => {
                if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].tag == .lparen) {
                    self.pos += 2;
                    const args_slice = self.parseArgs(false);
                    return self.arena.create(ZigAstNode, .{
                        .kind = .comp,
                        .has_ref_or_comp = true,
                        .is_fn = !isBuiltin(tok.slice),
                        .str_val = tok.slice,
                        .args = args_slice,
                    });
                } else {
                    self.pos += 1;
                    self.recordRef(tok.slice);
                    return self.arena.create(ZigAstNode, .{ .kind = .ref, .has_ref_or_comp = true, .str_val = tok.slice });
                }
            },
            .ident => {
                self.pos += 1;
                self.recordRef(tok.slice);
                return self.arena.create(ZigAstNode, .{ .kind = .ref, .has_ref_or_comp = true, .str_val = tok.slice });
            },
            .not_tok => {
                self.pos += 1;
                const operand = self.parseExpr(PREC_UNARY, false);
                return self.arena.create(ZigAstNode, .{
                    .kind = .unary_op,
                    .has_ref_or_comp = operand.has_ref_or_comp,
                    .str_val = "!",
                    .left = operand,
                });
            },
            .minus => {
                self.pos += 1;
                const operand = self.parseExpr(PREC_UNARY, false);
                return self.arena.create(ZigAstNode, .{
                    .kind = .unary_op,
                    .has_ref_or_comp = operand.has_ref_or_comp,
                    .str_val = "-",
                    .left = operand,
                });
            },
            .lparen => {
                self.pos += 1;
                const inner = self.parseExpr(0, false);
                self.eat(.rparen);
                return inner;
            },
            else => {
                self.pos += 1;
                return self.arena.create(ZigAstNode, .{ .kind = .null_node });
            },
        }
    }

    fn parseInfix(self: *NativeExprParser, left: *ZigAstNode) *ZigAstNode {
        const tok = self.tokens[self.pos];
        self.pos += 1;

        switch (tok.tag) {
            .plus, .minus, .star, .slash, .percent, .eq_eq, .not_eq, .greater, .less, .greater_eq, .less_eq, .and_tok, .or_tok => {
                const prec: u8 = switch (tok.tag) {
                    .plus, .minus => PREC_ADD,
                    .star, .slash, .percent => PREC_MUL,
                    .eq_eq, .not_eq => PREC_EQ,
                    .greater, .less, .greater_eq, .less_eq => PREC_CMP,
                    .and_tok => PREC_AND,
                    .or_tok => PREC_OR,
                    else => 0,
                };
                const op_str: []const u8 = switch (tok.tag) {
                    .plus => "+",
                    .minus => "-",
                    .star => "*",
                    .slash => "/",
                    .percent => "%",
                    .eq_eq => "==",
                    .not_eq => "!=",
                    .greater => ">",
                    .less => "<",
                    .greater_eq => ">=",
                    .less_eq => "<=",
                    .and_tok => "&&",
                    .or_tok => "||",
                    else => "+",
                };
                const right = self.parseExpr(prec, false);
                return self.arena.create(ZigAstNode, .{
                    .kind = .bin_op,
                    .has_ref_or_comp = left.has_ref_or_comp or right.has_ref_or_comp,
                    .str_val = op_str,
                    .left = left,
                    .right = right,
                });
            },
            .question => {
                const then_node = self.parseExpr(0, false);
                self.eat(.colon);
                const else_node = self.parseExpr(0, false);
                return self.arena.create(ZigAstNode, .{
                    .kind = .ternary,
                    .has_ref_or_comp = left.has_ref_or_comp or then_node.has_ref_or_comp or else_node.has_ref_or_comp,
                    .left = left,
                    .right = then_node,
                    .third = else_node,
                });
            },
            .dot => {
                const field_slice = self.parseKeyOrFieldSlice();
                return self.arena.create(ZigAstNode, .{
                    .kind = .member,
                    .has_ref_or_comp = left.has_ref_or_comp,
                    .str_val = field_slice,
                    .left = left,
                });
            },
            .lbrack => {
                const idx_node = self.parseExpr(0, false);
                self.eat(.rbrack);
                return self.arena.create(ZigAstNode, .{
                    .kind = .index,
                    .has_ref_or_comp = left.has_ref_or_comp or idx_node.has_ref_or_comp,
                    .left = left,
                    .right = idx_node,
                });
            },
            else => return left,
        }
    }

    fn parseArgs(self: *NativeExprParser, track_arg1: bool) []*ZigAstNode {
        var acc = Vec(*ZigAstNode).init(self.arena, 8);
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

    fn parseArr(self: *NativeExprParser) *ZigAstNode {
        var acc = Vec(*ZigAstNode).init(self.arena, 8);
        var has_rc = false;
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rbrack) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;
            const el = self.parseExpr(0, false);
            if (el.has_ref_or_comp) has_rc = true;
            self.eat(.comma);
            acc.append(el);
        }
        return self.arena.create(ZigAstNode, .{
            .kind = .arr,
            .has_ref_or_comp = has_rc,
            .args = acc.items,
        });
    }

    fn parseObj(self: *NativeExprParser) *ZigAstNode {
        var acc = Vec(ZigAstObjEntry).init(self.arena, 8);
        var has_rc = false;
        while (self.pos < self.tokens.len) {
            const t = self.tokens[self.pos].tag;
            if (t == .rbrace) {
                self.pos += 1;
                break;
            }
            if (t == .eof) break;
            const key_slice = self.parseKeyOrFieldSlice();
            self.eat(.colon);
            const val_node = self.parseExpr(0, false);
            if (val_node.has_ref_or_comp) has_rc = true;
            self.eat(.comma);
            acc.append(.{ .key = key_slice, .val = val_node });
        }
        return self.arena.create(ZigAstNode, .{
            .kind = .obj,
            .has_ref_or_comp = has_rc,
            .obj_entries = acc.items,
        });
    }

    fn parseKeyOrFieldSlice(self: *NativeExprParser) []const u8 {
        if (self.pos >= self.tokens.len) return "?";
        const tok = self.tokens[self.pos];
        self.pos += 1;
        return switch (tok.tag) {
            .ident, .type_tok, .str => tok.slice,
            .state_var => if (tok.slice.len > 0 and tok.slice[0] == '$') tok.slice[1..] else tok.slice,
            .num_int => {
                const buf = self.arena.alloc(u8, 32);
                return formatIntToSlice(buf, tok.int_val);
            },
            .num_float => tok.slice,
            else => "?",
        };
    }
};

fn parseStatementsToNative(arena: *BumpArena, closed: []const u8, need_refs: bool) []NativeParsedStmt {
    const tokens = tokenizeSlice(arena, closed);
    const raw_stmts = splitTokens(arena, tokens);
    if (raw_stmts.len == 0) return &[_]NativeParsedStmt{};

    var out = arena.alloc(NativeParsedStmt, raw_stmts.len);
    for (raw_stmts, 0..) |raw, idx| {
        var parser = NativeExprParser.init(arena, raw.tokens, need_refs);
        const expr = parser.parseExpr(0, true);
        const kind: StmtKind = if (parser.is_top_comp and std.mem.eql(u8, parser.top_comp_name, "Query"))
            .query
        else if (parser.is_top_comp and std.mem.eql(u8, parser.top_comp_name, "Mutation"))
            .mutation
        else if (raw.id_tag == .state_var)
            .state
        else
            .value;

        out[idx] = .{
            .id = raw.id,
            .id_hash = fnv1a32(raw.id),
            .kind = kind,
            .expr = expr,
            .state_refs = parser.state_refs.items,
            .refs = parser.refs.items,
            .deps = parser.arg1_deps.items,
        };
    }
    return out;
}

// ── Native Materialized Value & Schema Validator ─────────────────────────────

const ZigMatEntry = struct {
    key: []const u8,
    val: ZigMatVal,
};

const ZigMatObj = struct {
    entries: []ZigMatEntry,
    has_keys_meta: bool = true,
};

const ZigElementNode = struct {
    type_name: []const u8,
    props: []ZigMatEntry,
    partial: bool,
    has_dynamic_props: bool,
    statement_id: []const u8 = "",
    beam_cache_key: i64 = 0,
};

const ZigMatVal = union(enum) {
    null_val,
    bool_val: bool,
    int_val: i64,
    float_val: f64,
    str_val: []const u8,
    arr_val: []ZigMatVal,
    obj_val: *ZigMatObj,
    element_val: *ZigElementNode,
    ast_val: *ZigAstNode,
};

const ValidationError = struct {
    code: []const u8,
    component: []const u8,
    path: []const u8,
    message: []const u8,
    statement_id: []const u8 = "",
    has_statement_id: bool = false,
    is_warning: bool = false,
    beam_cache_key: i64 = 0,
};

fn containsDynamicValue(val: ZigMatVal) bool {
    return switch (val) {
        .null_val, .bool_val, .int_val, .float_val, .str_val => false,
        .ast_val => true,
        .element_val => |el| el.has_dynamic_props,
        .arr_val => |arr| {
            for (arr) |item| {
                if (containsDynamicValue(item)) return true;
            }
            return false;
        },
        .obj_val => |obj| {
            for (obj.entries) |e| {
                if (std.mem.eql(u8, e.key, "steps") and e.val == .arr_val) return true;
                if (containsDynamicValue(e.val)) return true;
            }
            return false;
        },
    };
}

fn defaultValToMatVal(arena: *BumpArena, dv: ZigDefaultVal) ZigMatVal {
    return switch (dv) {
        .null_val => .null_val,
        .bool_val => |b| .{ .bool_val = b },
        .int_val => |i| .{ .int_val = i },
        .float_val => |f| .{ .float_val = f },
        .str_val => |s| .{ .str_val = s },
        .arr_val => |arr| {
            var items = arena.alloc(ZigMatVal, arr.len);
            for (arr, 0..) |item, i| {
                items[i] = defaultValToMatVal(arena, item);
            }
            return .{ .arr_val = items };
        },
        .obj_val => |entries| {
            var mat_entries = arena.alloc(ZigMatEntry, entries.len);
            for (entries, 0..) |e, i| {
                mat_entries[i] = .{ .key = e.key, .val = defaultValToMatVal(arena, e.val) };
            }
            const obj = arena.create(ZigMatObj, .{ .entries = mat_entries, .has_keys_meta = false });
            return .{ .obj_val = obj };
        },
    };
}

fn literalValueFromAst(arena: *BumpArena, node: *const ZigAstNode) ?ZigMatVal {
    return switch (node.kind) {
        .str => .{ .str_val = node.str_val },
        .num_int => .{ .int_val = node.int_val },
        .num_float => .{ .float_val = node.float_val },
        .bool_node => .{ .bool_val = node.bool_val },
        .null_node => .null_val,
        .arr => {
            var items = arena.alloc(ZigMatVal, node.args.len);
            for (node.args, 0..) |el, i| {
                items[i] = literalValueFromAst(arena, el) orelse return null;
            }
            return .{ .arr_val = items };
        },
        .obj => {
            var entries = Vec(ZigMatEntry).init(arena, node.obj_entries.len);
            for (node.obj_entries) |e| {
                const v = literalValueFromAst(arena, e.val) orelse return null;
                var found: ?usize = null;
                for (entries.items, 0..) |existing, i| {
                    if (std.mem.eql(u8, existing.key, e.key)) {
                        found = i;
                        break;
                    }
                }
                if (found) |fi| {
                    entries.items[fi].val = v;
                } else {
                    entries.append(.{ .key = e.key, .val = v });
                }
            }
            const obj = arena.create(ZigMatObj, .{ .entries = entries.items, .has_keys_meta = false });
            return .{ .obj_val = obj };
        },
        else => null,
    };
}

fn matValToLiteralAst(arena: *BumpArena, val: ZigMatVal) *ZigAstNode {
    return switch (val) {
        .null_val => arena.create(ZigAstNode, .{ .kind = .null_node }),
        .bool_val => |b| arena.create(ZigAstNode, .{ .kind = .bool_node, .bool_val = b }),
        .int_val => |i| arena.create(ZigAstNode, .{ .kind = .num_int, .int_val = i }),
        .float_val => |f| arena.create(ZigAstNode, .{ .kind = .num_float, .float_val = f }),
        .str_val => |s| arena.create(ZigAstNode, .{ .kind = .str, .str_val = s }),
        .arr_val => |arr| {
            var els = arena.alloc(*ZigAstNode, arr.len);
            for (arr, 0..) |item, i| {
                els[i] = matValToLiteralAst(arena, item);
            }
            return arena.create(ZigAstNode, .{ .kind = .arr, .args = els });
        },
        .obj_val => |obj| {
            var entries = arena.alloc(ZigAstObjEntry, obj.entries.len);
            for (obj.entries, 0..) |e, i| {
                entries[i] = .{ .key = e.key, .val = matValToLiteralAst(arena, e.val) };
            }
            return arena.create(ZigAstNode, .{ .kind = .obj, .obj_entries = entries });
        },
        .ast_val => |ast| ast,
        .element_val => arena.create(ZigAstNode, .{ .kind = .null_node }),
    };
}

fn cloneAstToArena(arena: *BumpArena, node: *const ZigAstNode) *ZigAstNode {
    var copy = node.*;
    copy.str_val = arena.dupe(u8, node.str_val);
    if (node.args.len > 0) {
        var cargs = arena.alloc(*ZigAstNode, node.args.len);
        for (node.args, 0..) |a, i| cargs[i] = cloneAstToArena(arena, a);
        copy.args = cargs;
    }
    if (node.obj_entries.len > 0) {
        var centries = arena.alloc(ZigAstObjEntry, node.obj_entries.len);
        for (node.obj_entries, 0..) |e, i| {
            centries[i] = .{ .key = arena.dupe(u8, e.key), .val = cloneAstToArena(arena, e.val) };
        }
        copy.obj_entries = centries;
    }
    if (node.mapped_props) |mp| {
        var cmp = arena.alloc(ZigMappedProp, mp.len);
        for (mp, 0..) |p, i| {
            cmp[i] = .{ .key = arena.dupe(u8, p.key), .val = cloneAstToArena(arena, p.val) };
        }
        copy.mapped_props = cmp;
    }
    if (node.left) |l| copy.left = cloneAstToArena(arena, l);
    if (node.right) |r| copy.right = cloneAstToArena(arena, r);
    if (node.third) |t| copy.third = cloneAstToArena(arena, t);
    return arena.create(ZigAstNode, copy);
}

fn cloneMatValToArena(arena: *BumpArena, val: ZigMatVal) ZigMatVal {
    return switch (val) {
        .null_val => .null_val,
        .bool_val => |b| .{ .bool_val = b },
        .int_val => |i| .{ .int_val = i },
        .float_val => |f| .{ .float_val = f },
        .str_val => |s| .{ .str_val = arena.dupe(u8, s) },
        .arr_val => |arr| {
            var items = arena.alloc(ZigMatVal, arr.len);
            for (arr, 0..) |item, i| items[i] = cloneMatValToArena(arena, item);
            return .{ .arr_val = items };
        },
        .obj_val => |obj| {
            var entries = arena.alloc(ZigMatEntry, obj.entries.len);
            for (obj.entries, 0..) |e, i| {
                entries[i] = .{ .key = arena.dupe(u8, e.key), .val = cloneMatValToArena(arena, e.val) };
            }
            return .{ .obj_val = arena.create(ZigMatObj, .{ .entries = entries, .has_keys_meta = obj.has_keys_meta }) };
        },
        .element_val => |el| {
            var props = arena.alloc(ZigMatEntry, el.props.len);
            for (el.props, 0..) |p, i| {
                props[i] = .{ .key = arena.dupe(u8, p.key), .val = cloneMatValToArena(arena, p.val) };
            }
            return .{
                .element_val = arena.create(ZigElementNode, .{
                    .type_name = arena.dupe(u8, el.type_name),
                    .props = props,
                    .partial = el.partial,
                    .has_dynamic_props = el.has_dynamic_props,
                    .statement_id = arena.dupe(u8, el.statement_id),
                    .beam_cache_key = el.beam_cache_key,
                }),
            };
        },
        .ast_val => |ast| .{ .ast_val = cloneAstToArena(arena, ast) },
    };
}

fn astToTerm(env: ?*ErlNifEnv, arena: *BumpArena, node: *const ZigAstNode) ERL_NIF_TERM {
    switch (node.kind) {
        .str => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.v };
            var vals = [_]ERL_NIF_TERM{ A.str, makeBin(env, node.str_val) };
            return makeMap(env, &keys, &vals);
        },
        .num_int => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.v };
            var vals = [_]ERL_NIF_TERM{ A.num, nif_make_int64(env, node.int_val) };
            return makeMap(env, &keys, &vals);
        },
        .num_float => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.v };
            var vals = [_]ERL_NIF_TERM{ A.num, nif_make_double(env, node.float_val) };
            return makeMap(env, &keys, &vals);
        },
        .bool_node => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.v };
            var vals = [_]ERL_NIF_TERM{ A.bool_kind, if (node.bool_val) A.true_atom else A.false_atom };
            return makeMap(env, &keys, &vals);
        },
        .null_node => {
            var keys = [_]ERL_NIF_TERM{A.k};
            var vals = [_]ERL_NIF_TERM{A.null_atom};
            return makeMap(env, &keys, &vals);
        },
        .ph => {
            if (node.str_val.len > 0) {
                var keys = [_]ERL_NIF_TERM{ A.k, A.n };
                var vals = [_]ERL_NIF_TERM{ A.ph, makeBin(env, node.str_val) };
                return makeMap(env, &keys, &vals);
            } else {
                var keys = [_]ERL_NIF_TERM{A.k};
                var vals = [_]ERL_NIF_TERM{A.ph};
                return makeMap(env, &keys, &vals);
            }
        },
        .ref => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.n };
            var vals = [_]ERL_NIF_TERM{ A.ref, makeBin(env, node.str_val) };
            return makeMap(env, &keys, &vals);
        },
        .state_ref => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.n };
            var vals = [_]ERL_NIF_TERM{ A.state_ref, makeBin(env, node.str_val) };
            return makeMap(env, &keys, &vals);
        },
        .runtime_ref => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.n, A.ref_type };
            var vals = [_]ERL_NIF_TERM{ A.runtime_ref, makeBin(env, node.str_val), if (node.bool_val) A.mutation else A.query };
            return makeMap(env, &keys, &vals);
        },
        .arr => {
            var el_terms = arena.alloc(ERL_NIF_TERM, node.args.len);
            for (node.args, 0..) |a, i| el_terms[i] = astToTerm(env, arena, a);
            var keys = [_]ERL_NIF_TERM{ A.k, A.els };
            var vals = [_]ERL_NIF_TERM{ A.arr, makeList(env, el_terms) };
            return makeMap(env, &keys, &vals);
        },
        .obj => {
            var entry_terms = arena.alloc(ERL_NIF_TERM, node.obj_entries.len);
            for (node.obj_entries, 0..) |e, i| {
                entry_terms[i] = nif_make_tuple2(env, makeBin(env, e.key), astToTerm(env, arena, e.val));
            }
            var keys = [_]ERL_NIF_TERM{ A.k, A.entries };
            var vals = [_]ERL_NIF_TERM{ A.obj, makeList(env, entry_terms) };
            return makeMap(env, &keys, &vals);
        },
        .comp => {
            var arg_terms = arena.alloc(ERL_NIF_TERM, node.args.len);
            for (node.args, 0..) |a, i| arg_terms[i] = astToTerm(env, arena, a);
            const args_list = makeList(env, arg_terms);
            const name_bin = makeBin(env, node.str_val);

            var k_buf: [5]ERL_NIF_TERM = undefined;
            var v_buf: [5]ERL_NIF_TERM = undefined;
            k_buf[0] = A.k;
            v_buf[0] = A.comp;
            k_buf[1] = A.name;
            v_buf[1] = name_bin;
            k_buf[2] = A.args;
            v_buf[2] = args_list;
            var cnt: usize = 3;

            if (node.is_fn) {
                k_buf[cnt] = A.fn_key;
                v_buf[cnt] = A.true_atom;
                cnt += 1;
            }
            if (node.mapped_props) |mp| {
                var mp_keys = arena.alloc(ERL_NIF_TERM, mp.len);
                var mp_vals = arena.alloc(ERL_NIF_TERM, mp.len);
                for (mp, 0..) |p, i| {
                    mp_keys[i] = makeBin(env, p.key);
                    mp_vals[i] = astToTerm(env, arena, p.val);
                }
                k_buf[cnt] = A.mapped_props;
                v_buf[cnt] = makeMap(env, mp_keys, mp_vals);
                cnt += 1;
            }
            return makeMap(env, k_buf[0..cnt], v_buf[0..cnt]);
        },
        .bin_op => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.op, A.left, A.right };
            var vals = [_]ERL_NIF_TERM{
                A.bin_op,
                makeBin(env, node.str_val),
                astToTerm(env, arena, node.left.?),
                astToTerm(env, arena, node.right.?),
            };
            return makeMap(env, &keys, &vals);
        },
        .unary_op => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.op, A.operand };
            var vals = [_]ERL_NIF_TERM{
                A.unary_op,
                makeBin(env, node.str_val),
                astToTerm(env, arena, node.left.?),
            };
            return makeMap(env, &keys, &vals);
        },
        .ternary => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.cond_key, A.then_key, A.else_key };
            var vals = [_]ERL_NIF_TERM{
                A.ternary,
                astToTerm(env, arena, node.left.?),
                astToTerm(env, arena, node.right.?),
                astToTerm(env, arena, node.third.?),
            };
            return makeMap(env, &keys, &vals);
        },
        .member => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.obj, A.field };
            var vals = [_]ERL_NIF_TERM{
                A.member,
                astToTerm(env, arena, node.left.?),
                makeBin(env, node.str_val),
            };
            return makeMap(env, &keys, &vals);
        },
        .index => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.obj, A.index };
            var vals = [_]ERL_NIF_TERM{
                A.index,
                astToTerm(env, arena, node.left.?),
                astToTerm(env, arena, node.right.?),
            };
            return makeMap(env, &keys, &vals);
        },
        .assign => {
            var keys = [_]ERL_NIF_TERM{ A.k, A.target, A.value };
            var vals = [_]ERL_NIF_TERM{
                A.assign,
                makeBin(env, node.str_val),
                astToTerm(env, arena, node.left.?),
            };
            return makeMap(env, &keys, &vals);
        },
    }
}

fn elementToTerm(
    env: ?*ErlNifEnv,
    arena: *BumpArena,
    el: *const ZigElementNode,
    beam_mat_cache: ERL_NIF_TERM,
) ERL_NIF_TERM {
    if (el.beam_cache_key != 0 and beam_mat_cache != 0) {
        var cached: ERL_NIF_TERM = 0;
        if (nif_get_map_value(env, beam_mat_cache, nif_make_int64(env, el.beam_cache_key), &cached) != 0) {
            return cached;
        }
    }

    var prop_keys = arena.alloc(ERL_NIF_TERM, el.props.len);
    var prop_vals = arena.alloc(ERL_NIF_TERM, el.props.len);
    for (el.props, 0..) |p, i| {
        prop_keys[i] = makeBin(env, p.key);
        prop_vals[i] = matValToTerm(env, arena, p.val, true, beam_mat_cache);
    }
    const props_map = makeMap(env, prop_keys, prop_vals);

    var k_buf: [6]ERL_NIF_TERM = undefined;
    var v_buf: [6]ERL_NIF_TERM = undefined;
    k_buf[0] = A.type_tok;
    v_buf[0] = makeBin(env, "element");
    k_buf[1] = A.type_name;
    v_buf[1] = makeBin(env, el.type_name);
    k_buf[2] = A.props;
    v_buf[2] = props_map;
    k_buf[3] = A.partial;
    v_buf[3] = if (el.partial) A.true_atom else A.false_atom;
    k_buf[4] = A.has_dynamic_props;
    v_buf[4] = if (el.has_dynamic_props) A.true_atom else A.false_atom;
    var cnt: usize = 5;

    if (el.statement_id.len > 0) {
        k_buf[cnt] = A.statement_id;
        v_buf[cnt] = makeBin(env, el.statement_id);
        cnt += 1;
    }

    return makeMap(env, k_buf[0..cnt], v_buf[0..cnt]);
}

fn matValToTerm(
    env: ?*ErlNifEnv,
    arena: *BumpArena,
    val: ZigMatVal,
    include_keys_meta: bool,
    beam_mat_cache: ERL_NIF_TERM,
) ERL_NIF_TERM {
    return switch (val) {
        .null_val => A.nil_atom,
        .bool_val => |b| if (b) A.true_atom else A.false_atom,
        .int_val => |i| nif_make_int64(env, i),
        .float_val => |f| nif_make_double(env, f),
        .str_val => |s| makeBin(env, s),
        .arr_val => |arr| {
            var terms = arena.alloc(ERL_NIF_TERM, arr.len);
            for (arr, 0..) |item, i| {
                terms[i] = matValToTerm(env, arena, item, include_keys_meta, beam_mat_cache);
            }
            return makeList(env, terms);
        },
        .obj_val => |obj| {
            const add_keys = include_keys_meta and obj.has_keys_meta;
            const total = obj.entries.len + (if (add_keys) @as(usize, 1) else 0);
            const keys = arena.alloc(ERL_NIF_TERM, total);
            const vals = arena.alloc(ERL_NIF_TERM, total);
            const key_list_terms = arena.alloc(ERL_NIF_TERM, if (add_keys) obj.entries.len else 0);

            for (obj.entries, 0..) |e, i| {
                const k_term = makeBin(env, e.key);
                keys[i] = k_term;
                vals[i] = matValToTerm(env, arena, e.val, include_keys_meta, beam_mat_cache);
                if (add_keys) key_list_terms[i] = k_term;
            }
            if (add_keys) {
                keys[obj.entries.len] = makeBin(env, "__keys__");
                vals[obj.entries.len] = makeList(env, key_list_terms);
            }
            return makeMap(env, keys, vals);
        },
        .element_val => |el| elementToTerm(env, arena, el, beam_mat_cache),
        .ast_val => |ast| astToTerm(env, arena, ast),
    };
}

// ── Feature 1 & 2: Stateful Stream Resource & Native Materializer ────────────

fn validationErrorToTerm(
    env: ?*ErlNifEnv,
    e: ValidationError,
    beam_mat_cache: ERL_NIF_TERM,
) ERL_NIF_TERM {
    if (e.beam_cache_key != 0 and beam_mat_cache != 0) {
        var cached: ERL_NIF_TERM = 0;
        if (nif_get_map_value(env, beam_mat_cache, nif_make_int64(env, e.beam_cache_key), &cached) != 0) {
            return cached;
        }
    }
    const sid_term = if (e.has_statement_id) makeBin(env, e.statement_id) else A.nil_atom;
    var ek: [6]ERL_NIF_TERM = undefined;
    var ev: [6]ERL_NIF_TERM = undefined;
    ek[0] = A.code;
    ev[0] = makeBin(env, e.code);
    ek[1] = A.component;
    ev[1] = makeBin(env, e.component);
    ek[2] = A.path;
    ev[2] = makeBin(env, e.path);
    ek[3] = A.message;
    ev[3] = makeBin(env, e.message);
    ek[4] = A.statement_id;
    ev[4] = sid_term;
    var ecnt: usize = 5;
    if (e.is_warning) {
        ek[ecnt] = A.severity;
        ev[ecnt] = makeBin(env, "warning");
        ecnt += 1;
    }
    return makeMap(env, ek[0..ecnt], ev[0..ecnt]);
}

const StmtCacheSlot = struct {
    valid: bool = false,
    val: ZigMatVal = .null_val,
    errors: []ValidationError = &[_]ValidationError{},
    sub_reached: []u32 = &[_]u32{},
};

const CompletedStmt = struct {
    id: []const u8,
    id_hash: u32,
    kind: StmtKind,
    expr: *ZigAstNode,
    state_refs: [][]const u8,
    refs: [][]const u8,
    deps: [][]const u8,
    rev_deps: Vec(u32),
    next_in_bucket: i32 = -1,
    slots: [2]StmtCacheSlot = .{ .{}, .{} },
};

const ActiveStmt = struct {
    id: []const u8,
    id_hash: u32,
    kind: StmtKind,
    expr: *ZigAstNode,
    state_refs: [][]const u8,
    deps: [][]const u8,
    is_pending: bool = false,
    completed_idx: u32 = 0,
};

const ZigStreamResource = struct {
    schema: *const ZigSchema,
    root_name_ptr: ?[*]u8 = null,
    root_name_len: usize = 0,
    buf: ?[*]u8 = null,
    buf_len: usize = 0,
    buf_cap: usize = 0,
    cleaned: ?[*]u8 = null,
    cleaned_len: usize = 0,
    cleaned_cap: usize = 0,
    has_fences: bool = false,
    completed_raw_end: usize = 0,
    completed_end: usize = 0,
    completed_count: usize = 0,
    stmt_arena: BumpArena,
    completed_stmts: Vec(CompletedStmt),
    completed_buckets: [256]i32 = [_]i32{-1} ** 256,

    pub inline fn rootName(self: *const ZigStreamResource) []const u8 {
        if (self.root_name_len == 0 or self.root_name_ptr == null) return "";
        return self.root_name_ptr.?[0..self.root_name_len];
    }

    pub inline fn bufSlice(self: *const ZigStreamResource) []const u8 {
        if (self.buf_len == 0 or self.buf == null) return "";
        return self.buf.?[0..self.buf_len];
    }

    pub inline fn cleanedSlice(self: *const ZigStreamResource) []const u8 {
        if (self.cleaned_len == 0 or self.cleaned == null) return "";
        return self.cleaned.?[0..self.cleaned_len];
    }

    pub fn appendChunk(self: *ZigStreamResource, chunk: []const u8) void {
        if (chunk.len == 0) return;
        const needed = self.buf_len + chunk.len;
        if (needed > self.buf_cap) {
            var new_cap = if (self.buf_cap == 0) @max(@as(usize, 4096), needed * 2) else self.buf_cap * 2;
            while (new_cap < needed) new_cap *= 2;
            const new_ptr = nif_alloc(new_cap) orelse @panic("OpenUILang.ZigNIF: out of memory");
            if (self.buf_len > 0 and self.buf != null) {
                @memcpy(new_ptr[0..self.buf_len], self.buf.?[0..self.buf_len]);
            }
            nif_free(self.buf);
            self.buf = new_ptr;
            self.buf_cap = new_cap;
        }
        @memcpy(self.buf.?[self.buf_len .. self.buf_len + chunk.len], chunk);
        self.buf_len += chunk.len;
    }

    pub fn setCleaned(self: *ZigStreamResource, next: []const u8) void {
        if (next.len > self.cleaned_cap) {
            const new_cap = @max(@as(usize, 4096), next.len * 2);
            const new_ptr = nif_alloc(new_cap) orelse @panic("OpenUILang.ZigNIF: out of memory");
            nif_free(self.cleaned);
            self.cleaned = new_ptr;
            self.cleaned_cap = new_cap;
        }
        if (next.len > 0) {
            @memcpy(self.cleaned.?[0..next.len], next);
        }
        self.cleaned_len = next.len;
    }

    pub fn resetStateKeepingBuf(self: *ZigStreamResource) void {
        self.stmt_arena.deinit();
        self.stmt_arena = BumpArena.init(&[_]u8{});
        self.completed_stmts = Vec(CompletedStmt).init(&self.stmt_arena, 32);
        self.completed_buckets = [_]i32{-1} ** 256;
        self.completed_end = 0;
        self.completed_raw_end = 0;
        self.completed_count = 0;
    }

    pub fn resetFull(self: *ZigStreamResource) void {
        self.buf_len = 0;
        self.cleaned_len = 0;
        self.has_fences = false;
        self.resetStateKeepingBuf();
    }

    pub inline fn findCompletedIdx(self: *const ZigStreamResource, hash: u32, id: []const u8) ?u32 {
        var idx = self.completed_buckets[hash & 255];
        while (idx >= 0) {
            const u_idx: usize = @intCast(idx);
            const s = &self.completed_stmts.items[u_idx];
            if (s.id_hash == hash and std.mem.eql(u8, s.id, id)) return @intCast(u_idx);
            idx = s.next_in_bucket;
        }
        return null;
    }

    pub fn clearAllSlots(self: *ZigStreamResource) void {
        for (self.completed_stmts.items) |*s| {
            s.slots[0].valid = false;
            s.slots[1].valid = false;
        }
    }

    pub fn invalidateFromIdx(
        self: *ZigStreamResource,
        env: ?*ErlNifEnv,
        temp_arena: *BumpArena,
        start_idx: u32,
        beam_cache: *ERL_NIF_TERM,
    ) void {
        const len = self.completed_stmts.items.len;
        if (start_idx >= len) return;
        const first = &self.completed_stmts.items[start_idx];
        if (!first.slots[0].valid and !first.slots[1].valid and first.rev_deps.items.len == 0) {
            return;
        }
        var seen = temp_arena.alloc(bool, len);
        @memset(seen, false);
        var queue = Vec(u32).init(temp_arena, 16);
        queue.append(start_idx);
        seen[start_idx] = true;

        var q_pos: usize = 0;
        while (q_pos < queue.items.len) : (q_pos += 1) {
            const idx = queue.items[q_pos];
            var cstmt = &self.completed_stmts.items[idx];
            if (cstmt.slots[0].valid or cstmt.slots[1].valid) {
                if (beam_cache.* != 0) {
                    const k0 = nif_make_int64(env, ((@as(i64, @intCast(idx)) + 1) << 1) | 0);
                    const k1 = nif_make_int64(env, ((@as(i64, @intCast(idx)) + 1) << 1) | 1);
                    var next_map: ERL_NIF_TERM = 0;
                    if (nif_make_map_remove(env, beam_cache.*, k0, &next_map) != 0) beam_cache.* = next_map;
                    if (nif_make_map_remove(env, beam_cache.*, k1, &next_map) != 0) beam_cache.* = next_map;
                    for (cstmt.slots[0].errors) |e| {
                        if (e.beam_cache_key != 0) {
                            if (nif_make_map_remove(env, beam_cache.*, nif_make_int64(env, e.beam_cache_key), &next_map) != 0) beam_cache.* = next_map;
                        }
                    }
                    for (cstmt.slots[1].errors) |e| {
                        if (e.beam_cache_key != 0) {
                            if (nif_make_map_remove(env, beam_cache.*, nif_make_int64(env, e.beam_cache_key), &next_map) != 0) beam_cache.* = next_map;
                        }
                    }
                }
                cstmt.slots[0].valid = false;
                cstmt.slots[1].valid = false;
            }
            for (cstmt.rev_deps.items) |parent_idx| {
                if (parent_idx < len and !seen[parent_idx]) {
                    seen[parent_idx] = true;
                    queue.append(parent_idx);
                }
            }
        }
    }

    pub fn addCompletedStmtSlice(
        self: *ZigStreamResource,
        env: ?*ErlNifEnv,
        temp_arena: *BumpArena,
        slice: []const u8,
        beam_cache: *ERL_NIF_TERM,
    ) void {
        const trimmed = trimAscii(slice);
        if (trimmed.len == 0) return;

        const owned_src = self.stmt_arena.dupe(u8, trimmed);
        const parsed = parseStatementsToNative(&self.stmt_arena, owned_src, true);

        for (parsed) |p| {
            self.completed_count += 1;
            if (self.findCompletedIdx(p.id_hash, p.id)) |existing_idx| {
                var target = &self.completed_stmts.items[existing_idx];
                target.kind = p.kind;
                target.expr = p.expr;
                target.state_refs = p.state_refs;
                target.refs = p.refs;
                target.deps = p.deps;
                self.clearAllSlots();
                beam_cache.* = nif_make_new_map(env);
            } else {
                const new_idx: u32 = @intCast(self.completed_stmts.items.len);
                const bucket = p.id_hash & 255;
                const prev_head = self.completed_buckets[bucket];
                self.completed_buckets[bucket] = @intCast(new_idx);
                self.completed_stmts.append(.{
                    .id = p.id,
                    .id_hash = p.id_hash,
                    .kind = p.kind,
                    .expr = p.expr,
                    .state_refs = p.state_refs,
                    .refs = p.refs,
                    .deps = p.deps,
                    .rev_deps = Vec(u32).init(&self.stmt_arena, 4),
                    .next_in_bucket = prev_head,
                });

                // Wire rev_deps for any existing completed statement referenced by this new statement
                for (p.refs) |ref_name| {
                    const rhash = fnv1a32(ref_name);
                    if (self.findCompletedIdx(rhash, ref_name)) |ref_idx| {
                        var ref_stmt = &self.completed_stmts.items[ref_idx];
                        var already = false;
                        for (ref_stmt.rev_deps.items) |d| {
                            if (d == new_idx) {
                                already = true;
                                break;
                            }
                        }
                        if (!already) ref_stmt.rev_deps.append(new_idx);
                    }
                }

                // Also check if any earlier completed statement had forward-referenced `p.id`
                for (self.completed_stmts.items[0..new_idx], 0..) |*earlier, e_idx| {
                    for (earlier.refs) |eref| {
                        if (std.mem.eql(u8, eref, p.id)) {
                            var new_stmt = &self.completed_stmts.items[new_idx];
                            new_stmt.rev_deps.append(@intCast(e_idx));
                            break;
                        }
                    }
                }

                self.invalidateFromIdx(env, temp_arena, new_idx, beam_cache);
            }
        }
    }

    pub fn scanCompletedSlice(
        self: *ZigStreamResource,
        env: ?*ErlNifEnv,
        temp_arena: *BumpArena,
        cleaned: []const u8,
        start_pos: usize,
        beam_cache: *ERL_NIF_TERM,
    ) struct { pending_start: usize, last_completed_end: usize } {
        var i: usize = start_pos;
        var stmt_start: usize = start_pos;
        var last_completed: usize = 0;
        var depth: i32 = 0;
        var tdepth: i32 = 0;
        var in_str: u8 = 0;

        while (i < cleaned.len) {
            const c = cleaned[i];
            if (in_str != 0) {
                if (c == '\\' and i + 1 < cleaned.len) {
                    i += 2;
                } else {
                    if (c == in_str) in_str = 0;
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
                    '?' => {
                        if (depth == 0) tdepth += 1;
                        i += 1;
                    },
                    ':' => {
                        if (depth == 0 and tdepth > 0) tdepth -= 1;
                        i += 1;
                    },
                    '\n' => {
                        if (depth <= 0 and tdepth <= 0) {
                            var peek_idx = i + 1;
                            while (peek_idx < cleaned.len and isAsciiWs(cleaned[peek_idx])) : (peek_idx += 1) {}
                            const peek_ch: u8 = if (peek_idx < cleaned.len) cleaned[peek_idx] else 0;
                            if (peek_ch == '?' or (peek_ch == ':' and tdepth > 0)) {
                                i += 1;
                            } else {
                                const slice = cleaned[stmt_start..i];
                                self.addCompletedStmtSlice(env, temp_arena, slice, beam_cache);
                                stmt_start = i + 1;
                                last_completed = i + 1;
                                i += 1;
                            }
                        } else {
                            i += 1;
                        }
                    },
                    else => i += 1,
                }
            }
        }

        return .{ .pending_start = stmt_start, .last_completed_end = last_completed };
    }

    pub fn advanceStream(
        self: *ZigStreamResource,
        env: ?*ErlNifEnv,
        temp_arena: *BumpArena,
        beam_cache: *ERL_NIF_TERM,
    ) []const u8 {
        const raw_buf = self.bufSlice();
        const fence_check_pos = if (self.completed_raw_end >= 2) self.completed_raw_end - 2 else 0;
        const newly_fenced = !self.has_fences and raw_buf.len >= fence_check_pos + 3 and
            (std.mem.indexOf(u8, raw_buf[fence_check_pos..], "```") != null);

        if (newly_fenced) {
            if (self.completed_raw_end > 0) {
                self.resetStateKeepingBuf();
                beam_cache.* = nif_make_new_map(env);
            }
            self.has_fences = true;
        }

        if (!self.has_fences and raw_buf.len >= self.completed_raw_end) {
            const raw_tail = raw_buf[self.completed_raw_end..];
            const maybe_comments = (std.mem.indexOf(u8, raw_tail, "//") != null) or
                (std.mem.indexOf(u8, raw_tail, "/*") != null) or
                (std.mem.indexOfScalar(u8, raw_tail, '#') != null);

            var cleaned_tail = if (maybe_comments) stripComments(temp_arena, raw_tail) else raw_tail;
            const comments_stripped = (cleaned_tail.ptr != raw_tail.ptr);
            while (cleaned_tail.len > 0 and isAsciiWs(cleaned_tail[cleaned_tail.len - 1])) {
                cleaned_tail = cleaned_tail[0 .. cleaned_tail.len - 1];
            }

            const scan_res = self.scanCompletedSlice(env, temp_arena, cleaned_tail, 0, beam_cache);
            if (scan_res.last_completed_end > 0) {
                if (!comments_stripped) {
                    self.completed_raw_end += scan_res.last_completed_end;
                } else {
                    var nl_count: usize = 0;
                    for (cleaned_tail[0..scan_res.last_completed_end]) |ch| {
                        if (ch == '\n') nl_count += 1;
                    }
                    var pos = self.completed_raw_end;
                    while (pos < raw_buf.len and nl_count > 0) : (pos += 1) {
                        if (raw_buf[pos] == '\n') nl_count -= 1;
                    }
                    self.completed_raw_end = pos;
                }
            }

            return trimAscii(cleaned_tail[scan_res.pending_start..]);
        } else {
            const next_cleaned = preprocessSlice(temp_arena, raw_buf);
            const cur_cleaned = self.cleanedSlice();
            const prefix_len = @min(self.completed_end, cur_cleaned.len);
            if (!std.mem.startsWith(u8, next_cleaned, cur_cleaned[0..prefix_len])) {
                self.resetStateKeepingBuf();
                beam_cache.* = nif_make_new_map(env);
            }
            self.setCleaned(next_cleaned);
            const updated_cleaned = self.cleanedSlice();
            const scan_res = self.scanCompletedSlice(env, temp_arena, updated_cleaned, self.completed_end, beam_cache);
            if (scan_res.last_completed_end > 0) {
                self.completed_end = scan_res.last_completed_end;
            }
            return trimAscii(updated_cleaned[scan_res.pending_start..]);
        }
    }
};

fn streamResourceDtor(_env: ?*ErlNifEnv, obj: ?*anyopaque) callconv(.c) void {
    _ = _env;
    if (obj == null) return;
    const stream: *ZigStreamResource = @ptrCast(@alignCast(obj.?));
    stream.stmt_arena.deinit();
    nif_free(stream.buf);
    nif_free(stream.cleaned);
    nif_free(stream.root_name_ptr);
}

fn detectPartialStateTailNative(raw_buf: []const u8, pending_text: []const u8, complete: bool) ?[]const u8 {
    if (complete or raw_buf.len < 2) return null;
    var i: usize = raw_buf.len;
    while (i > 0) {
        i -= 1;
        const c = raw_buf[i];
        if (isIdentCont(c)) {
            if (i == 0) return null;
            continue;
        }
        if (c == '$' and i < raw_buf.len - 1) {
            const tail = raw_buf[i..];
            if (pending_text.len >= tail.len and std.mem.endsWith(u8, pending_text, tail)) {
                const before_tail = pending_text[0 .. pending_text.len - tail.len];
                var search_pos: usize = 0;
                while (std.mem.indexOfPos(u8, before_tail, search_pos, tail)) |match_pos| {
                    const after_pos = match_pos + tail.len;
                    if (after_pos >= before_tail.len or !isIdentCont(before_tail[after_pos])) {
                        return null;
                    }
                    search_pos = match_pos + 1;
                }
                return tail;
            }
            return null;
        }
        return null;
    }
    return null;
}

// ── Materializer & Schema Validation Engine ──────────────────────────────────

fn jsTypeof(val: ZigMatVal) []const u8 {
    return switch (val) {
        .str_val => "string",
        .int_val, .float_val => "number",
        .bool_val => "boolean",
        else => "object",
    };
}

fn jsType(val: ZigMatVal) []const u8 {
    return switch (val) {
        .arr_val => "array",
        else => jsTypeof(val),
    };
}

fn jsonEncodeScalar(arena: *BumpArena, val: ZigMatVal) []const u8 {
    return switch (val) {
        .bool_val => |b| if (b) "true" else "false",
        .int_val => |i| {
            const buf = arena.alloc(u8, 32);
            return formatIntToSlice(buf, i);
        },
        .float_val => |f| {
            const buf = arena.alloc(u8, 64);
            const len = nif_format_double(f, buf.ptr, buf.len);
            return buf[0..len];
        },
        .str_val => |s| {
            var out = Vec(u8).init(arena, s.len + 4);
            out.append('"');
            for (s) |c| {
                switch (c) {
                    '"' => out.appendSlice("\\\""),
                    '\\' => out.appendSlice("\\\\"),
                    '\n' => out.appendSlice("\\n"),
                    '\r' => out.appendSlice("\\r"),
                    '\t' => out.appendSlice("\\t"),
                    0x08 => out.appendSlice("\\b"),
                    0x0C => out.appendSlice("\\f"),
                    else => out.append(c),
                }
            }
            out.append('"');
            return out.items;
        },
        else => "null",
    };
}

fn scalarMatchesEnumVal(val: ZigMatVal, ev: ZigDefaultVal) bool {
    return switch (val) {
        .str_val => |s| (ev == .str_val and std.mem.eql(u8, s, ev.str_val)),
        .bool_val => |b| (ev == .bool_val and b == ev.bool_val),
        .int_val => |i| switch (ev) {
            .int_val => |ei| i == ei,
            .float_val => |ef| @as(f64, @floatFromInt(i)) == ef,
            else => false,
        },
        .float_val => |f| switch (ev) {
            .float_val => |ef| f == ef,
            .int_val => |ei| f == @as(f64, @floatFromInt(ei)),
            else => false,
        },
        else => false,
    };
}

fn concat2(arena: *BumpArena, a: []const u8, b: []const u8) []const u8 {
    const out = arena.alloc(u8, a.len + b.len);
    if (a.len > 0) @memcpy(out[0..a.len], a);
    if (b.len > 0) @memcpy(out[a.len..], b);
    return out;
}

fn concatPath(arena: *BumpArena, base: []const u8, sub: []const u8) []const u8 {
    const out = arena.alloc(u8, base.len + 1 + sub.len);
    if (base.len > 0) @memcpy(out[0..base.len], base);
    out[base.len] = '/';
    if (sub.len > 0) @memcpy(out[base.len + 1 ..], sub);
    return out;
}

const ValidateResult = struct {
    valid: bool,
    val: ZigMatVal,
};

const Materializer = struct {
    env: ?*ErlNifEnv,
    arena: *BumpArena,
    schema: *const ZigSchema,
    stmts: []const ActiveStmt,
    stmt_buckets: [256]i32,
    stmt_next: []const i32,
    stream: ?*ZigStreamResource = null,
    beam_mat_cache: ERL_NIF_TERM = 0,
    partial: bool,
    used_partial_lenient: bool = false,
    current_statement_id: []const u8 = "",
    has_current_id: bool = false,
    in_pending: bool = false,
    visited: []bool,
    unreached: []bool,
    errors: Vec(ValidationError),
    unres: Vec([]const u8),

    pub inline fn findStmtIdx(self: *const Materializer, hash: u32, name: []const u8) ?usize {
        var idx = self.stmt_buckets[hash & 255];
        while (idx >= 0) {
            const u_idx: usize = @intCast(idx);
            const s = &self.stmts[u_idx];
            if (s.id_hash == hash and std.mem.eql(u8, s.id, name)) return u_idx;
            idx = self.stmt_next[u_idx];
        }
        return null;
    }

    pub inline fn isRuntimeCall(self: *const Materializer, hash: u32, name: []const u8) bool {
        return self.schema.findCallDef(hash, name) != null or isReservedCall(name);
    }

    pub fn pushError(self: *Materializer, code: []const u8, component: []const u8, path: []const u8, message: []const u8, is_warning: bool) void {
        self.errors.append(.{
            .code = code,
            .component = component,
            .path = path,
            .message = message,
            .statement_id = self.current_statement_id,
            .has_statement_id = self.has_current_id,
            .is_warning = is_warning,
        });
    }

    pub fn pushTypeMismatch(self: *Materializer, component: []const u8, path: []const u8, expected: []const u8, actual: []const u8) void {
        var msg = Vec(u8).init(self.arena, path.len + expected.len + actual.len + 32);
        msg.appendSlice("field \"");
        msg.appendSlice(path);
        msg.appendSlice("\" expects ");
        msg.appendSlice(expected);
        msg.appendSlice(" but got ");
        msg.appendSlice(actual);
        self.pushError("type-mismatch", component, path, msg.items, false);
    }

    pub fn pushMissingOrNullRequired(self: *Materializer, is_null: bool, component: []const u8, path: []const u8, signature: []const u8) void {
        var msg = Vec(u8).init(self.arena, path.len + signature.len + 48);
        if (is_null) {
            msg.appendSlice("required field \"");
            msg.appendSlice(path);
            msg.appendSlice("\" cannot be null");
        } else {
            msg.appendSlice("missing required field \"");
            msg.appendSlice(path);
            msg.append('"');
        }
        if (signature.len > 0) {
            msg.appendSlice(" — signature: ");
            msg.appendSlice(signature);
        }
        self.pushError(if (is_null) "null-required" else "missing-required", component, path, msg.items, false);
    }

    pub fn pushUnknownComponent(self: *Materializer, component: []const u8) void {
        var msg = Vec(u8).init(self.arena, component.len + self.schema.avail_suffix.len + 64);
        msg.appendSlice("Unknown component \"");
        msg.appendSlice(component);
        msg.appendSlice("\" — not found in catalog or builtins");
        msg.appendSlice(self.schema.avail_suffix);
        self.pushError("unknown-component", component, "", msg.items, false);
    }

    pub fn pushInlineReserved(self: *Materializer, component: []const u8) void {
        const msg = concat2(self.arena, component, "() must be declared as a top-level statement, not used inline as a value");
        self.pushError("inline-reserved", component, "", msg, false);
    }

    pub fn pushExcessArgs(self: *Materializer, component: []const u8, declared: usize, got: usize) void {
        var b1: [32]u8 = undefined;
        var b2: [32]u8 = undefined;
        var b3: [32]u8 = undefined;
        const s_dec = formatIntToSlice(&b1, @intCast(declared));
        const s_got = formatIntToSlice(&b2, @intCast(got));
        const s_exc = formatIntToSlice(&b3, @intCast(got - declared));

        var msg = Vec(u8).init(self.arena, component.len + 48);
        msg.appendSlice(component);
        msg.appendSlice(" takes ");
        msg.appendSlice(s_dec);
        msg.appendSlice(" arg(s), got ");
        msg.appendSlice(s_got);
        msg.appendSlice(" (");
        msg.appendSlice(s_exc);
        msg.appendSlice(" excess dropped)");
        self.pushError("excess-args", component, "", msg.items, false);
    }

    pub fn pushUnknownFunction(self: *Materializer, component: []const u8) void {
        var msg = Vec(u8).init(self.arena, component.len + 80);
        msg.appendSlice("Unknown function \"@");
        msg.appendSlice(component);
        msg.appendSlice("\": not a built-in or action step. The call evaluates to null");
        self.pushError("unknown-function", component, "", msg.items, false);
    }

    pub fn pushNoRoot(self: *Materializer, component: []const u8, reason: u8) void {
        // reason: 0 = missing, 1 = not-component, 2 = fallback
        if (reason == 1) {
            self.pushError("no-root", component, "", "root does not evaluate to a component", false);
        } else if (reason == 2) {
            const msg = concat2(self.arena, "No root statement. Rendering the first statement that calls the root component ", component);
            self.pushError("no-root", component, "", msg, true);
        } else {
            if (component.len > 0) {
                const msg = concat2(self.arena, "No root statement, and no statement calls the root component ", component);
                self.pushError("no-root", component, "", msg, false);
            } else {
                self.pushError("no-root", component, "", "No root statement", false);
            }
        }
    }

    pub fn validateSchemaValue(
        self: *Materializer,
        val: ZigMatVal,
        schema: *const SchemaNode,
        component: []const u8,
        path: []const u8,
    ) ValidateResult {
        if (val == .null_val or val == .ast_val) {
            return .{ .valid = true, .val = val };
        }
        if (val == .element_val) {
            if (schema.elem_reject_expected.len > 0) {
                var act = Vec(u8).init(self.arena, val.element_val.type_name.len + 14);
                act.appendSlice("component \"");
                act.appendSlice(val.element_val.type_name);
                act.append('"');
                self.pushTypeMismatch(component, path, schema.elem_reject_expected, act.items);
                return .{ .valid = false, .val = val };
            }
            return .{ .valid = true, .val = val };
        }

        switch (schema.kind) {
            .composite => {
                if (schema.only_component_slot) {
                    const act: []const u8 = switch (val) {
                        .arr_val => "array",
                        .obj_val => "plain object",
                        else => jsTypeof(val),
                    };
                    self.pushTypeMismatch(component, path, schema.slot_expected, act);
                    return .{ .valid = false, .val = val };
                }
                return .{ .valid = true, .val = val };
            },
            .object => {
                if (val != .obj_val) {
                    self.pushTypeMismatch(component, path, "object", jsType(val));
                    return .{ .valid = false, .val = val };
                }
                const orig_obj = val.obj_val;
                var entries = Vec(ZigMatEntry).init(self.arena, orig_obj.entries.len + schema.required.len);
                entries.appendSlice(orig_obj.entries);
                var invalid = false;

                for (schema.required) |req| {
                    var found_idx: ?usize = null;
                    for (entries.items, 0..) |e, i| {
                        if (std.mem.eql(u8, e.key, req.name)) {
                            found_idx = i;
                            break;
                        }
                    }
                    const present = (found_idx != null);
                    const is_nil = if (found_idx) |fi| (entries.items[fi].val == .null_val) else true;
                    if (!present or is_nil) {
                        if (self.partial) {
                            self.used_partial_lenient = true;
                        } else if (req.has_default) {
                            const def_mat = defaultValToMatVal(self.arena, req.default_val);
                            if (found_idx) |fi| {
                                entries.items[fi].val = def_mat;
                            } else {
                                entries.append(.{ .key = req.name, .val = def_mat });
                            }
                        } else {
                            const sub_path = concatPath(self.arena, path, req.name);
                            self.pushMissingOrNullRequired(present, component, sub_path, "");
                            invalid = true;
                        }
                    }
                }

                for (schema.props) |prop| {
                    var found_idx: ?usize = null;
                    for (entries.items, 0..) |e, i| {
                        if (std.mem.eql(u8, e.key, prop.name)) {
                            found_idx = i;
                            break;
                        }
                    }
                    if (found_idx) |fi| {
                        if (prop.has_schema) {
                            const sub_path = concatPath(self.arena, path, prop.name);
                            const res = self.validateSchemaValue(entries.items[fi].val, &prop.schema, component, sub_path);
                            if (res.valid) {
                                entries.items[fi].val = res.val;
                            } else {
                                if (prop.has_default) {
                                    entries.items[fi].val = defaultValToMatVal(self.arena, prop.default_val);
                                } else if (!prop.required) {
                                    var k = fi;
                                    while (k + 1 < entries.items.len) : (k += 1) {
                                        entries.items[k] = entries.items[k + 1];
                                    }
                                    entries.items.len -= 1;
                                } else {
                                    invalid = true;
                                }
                            }
                        }
                    }
                }

                if (invalid) return .{ .valid = false, .val = val };
                const new_obj = self.arena.create(ZigMatObj, .{
                    .entries = entries.items,
                    .has_keys_meta = orig_obj.has_keys_meta,
                });
                return .{ .valid = true, .val = .{ .obj_val = new_obj } };
            },
            .array => {
                if (val != .arr_val) {
                    self.pushTypeMismatch(component, path, "array", jsType(val));
                    return .{ .valid = false, .val = val };
                }
                if (!schema.has_items or schema.items == null) {
                    return .{ .valid = true, .val = val };
                }
                const items_schema = schema.items.?;
                const arr = val.arr_val;

                if (items_schema.kind == .composite) {
                    var all_el_or_ast = true;
                    for (arr) |item| {
                        if (item != .element_val and item != .ast_val) {
                            all_el_or_ast = false;
                            break;
                        }
                    }
                    if (all_el_or_ast) return .{ .valid = true, .val = val };
                }

                var out_items = Vec(ZigMatVal).init(self.arena, arr.len);
                for (arr, 0..) |item, idx| {
                    if (item == .element_val and items_schema.kind == .composite) {
                        out_items.append(item);
                    } else {
                        var ibuf: [32]u8 = undefined;
                        const idx_str = formatIntToSlice(&ibuf, @intCast(idx));
                        const item_path = concatPath(self.arena, path, idx_str);
                        const res = self.validateSchemaValue(item, items_schema, component, item_path);
                        if (res.valid) out_items.append(res.val);
                    }
                }
                return .{ .valid = true, .val = .{ .arr_val = out_items.items } };
            },
            .leaf => {
                switch (schema.leaf_kind) {
                    0 => return .{ .valid = true, .val = val },
                    1 => {
                        if (val == .str_val) return .{ .valid = true, .val = val };
                        self.pushTypeMismatch(component, path, "string", jsType(val));
                        return .{ .valid = false, .val = val };
                    },
                    2 => {
                        if (val == .int_val or val == .float_val) return .{ .valid = true, .val = val };
                        self.pushTypeMismatch(component, path, "number", jsType(val));
                        return .{ .valid = false, .val = val };
                    },
                    3 => {
                        if (val == .bool_val) return .{ .valid = true, .val = val };
                        self.pushTypeMismatch(component, path, "boolean", jsType(val));
                        return .{ .valid = false, .val = val };
                    },
                    4 => {
                        if (val != .str_val and val != .int_val and val != .float_val and val != .bool_val) {
                            return .{ .valid = true, .val = val };
                        }
                        for (schema.enum_vals) |ev| {
                            if (scalarMatchesEnumVal(val, ev)) return .{ .valid = true, .val = val };
                        }
                        if (self.partial) {
                            self.used_partial_lenient = true;
                            return .{ .valid = true, .val = val };
                        }
                        const act = jsonEncodeScalar(self.arena, val);
                        self.pushTypeMismatch(component, path, schema.enum_expected, act);
                        return .{ .valid = false, .val = val };
                    },
                    else => return .{ .valid = true, .val = val },
                }
            },
        }
    }

    pub fn nameArgs(self: *Materializer, args: []const *ZigAstNode, params: []const ParamDef) []ZigMappedProp {
        const count = @min(args.len, params.len);
        var out = self.arena.alloc(ZigMappedProp, count);
        for (0..count) |i| {
            out[i] = .{ .key = params[i].name, .val = args[i] };
        }
        return out;
    }

    pub fn mapCallArgs(
        self: *Materializer,
        name: []const u8,
        args: []const *ZigAstNode,
        def_info: *const CallDef,
    ) ?[]ZigMappedProp {
        const params = def_info.params;
        if (args.len > params.len) {
            self.pushExcessArgs(name, params.len, args.len);
        }

        var mapped = Vec(ZigMappedProp).init(self.arena, params.len);
        const init_cnt = @min(args.len, params.len);
        for (0..init_cnt) |i| {
            mapped.append(.{ .key = params[i].name, .val = args[i] });
        }

        const errors_before = self.errors.items.len;
        var invalid = false;

        for (params) |p| {
            var found_idx: ?usize = null;
            for (mapped.items, 0..) |mp, idx| {
                if (std.mem.eql(u8, mp.key, p.name)) {
                    found_idx = idx;
                    break;
                }
            }

            if (found_idx) |fi| {
                const arg_ast = mapped.items[fi].val;
                if (literalValueFromAst(self.arena, arg_ast)) |lit_val| {
                    if (lit_val == .null_val) {
                        if (p.required and !p.has_default) {
                            self.pushMissingOrNullRequired(true, name, p.path, def_info.signature);
                            invalid = true;
                        }
                    } else if (p.has_schema) {
                        const res = self.validateSchemaValue(lit_val, &p.schema, name, p.path);
                        if (res.valid) {
                            mapped.items[fi].val = matValToLiteralAst(self.arena, res.val);
                        } else {
                            if (p.has_default) {
                                const def_mat = defaultValToMatVal(self.arena, p.default_val);
                                mapped.items[fi].val = matValToLiteralAst(self.arena, def_mat);
                            } else if (!p.required) {
                                var k = fi;
                                while (k + 1 < mapped.items.len) : (k += 1) {
                                    mapped.items[k] = mapped.items[k + 1];
                                }
                                mapped.items.len -= 1;
                            } else {
                                invalid = true;
                            }
                        }
                    }
                }
            } else {
                if (p.required and !p.has_default) {
                    self.pushMissingOrNullRequired(false, name, p.path, def_info.signature);
                    invalid = true;
                }
            }
        }

        if (def_info.is_action and self.errors.items.len > errors_before) {
            invalid = true;
        }
        return if (invalid) null else mapped.items;
    }

    pub fn nameRawCallArgs(self: *Materializer, args: []const *ZigAstNode, statement_id: []const u8) []*ZigAstNode {
        const prev_id = self.current_statement_id;
        const prev_has = self.has_current_id;
        self.current_statement_id = statement_id;
        self.has_current_id = true;
        defer {
            self.current_statement_id = prev_id;
            self.has_current_id = prev_has;
        }

        var out = self.arena.alloc(*ZigAstNode, args.len);
        for (args, 0..) |a, i| {
            out[i] = self.nameRawNode(a);
        }
        return out;
    }

    pub fn nameRawNode(self: *Materializer, node: *const ZigAstNode) *ZigAstNode {
        if (!node.has_ref_or_comp) return @constCast(node);

        switch (node.kind) {
            .comp => {
                var new_args = self.arena.alloc(*ZigAstNode, node.args.len);
                for (node.args, 0..) |a, i| new_args[i] = self.nameRawNode(a);
                var copy = node.*;
                copy.args = new_args;

                const h = fnv1a32(node.str_val);
                if (self.schema.findCallDef(h, node.str_val)) |def_info| {
                    if (!def_info.is_lazy) {
                        const checked = if (def_info.is_builtin) null else self.mapCallArgs(node.str_val, new_args, def_info);
                        copy.mapped_props = checked orelse self.nameArgs(new_args, def_info.params);
                    }
                }
                return self.arena.create(ZigAstNode, copy);
            },
            .arr => {
                var new_els = self.arena.alloc(*ZigAstNode, node.args.len);
                for (node.args, 0..) |e, i| new_els[i] = self.nameRawNode(e);
                var copy = node.*;
                copy.args = new_els;
                return self.arena.create(ZigAstNode, copy);
            },
            .obj => {
                var new_entries = self.arena.alloc(ZigAstObjEntry, node.obj_entries.len);
                for (node.obj_entries, 0..) |e, i| {
                    new_entries[i] = .{ .key = e.key, .val = self.nameRawNode(e.val) };
                }
                var copy = node.*;
                copy.obj_entries = new_entries;
                return self.arena.create(ZigAstNode, copy);
            },
            .bin_op, .index => {
                var copy = node.*;
                copy.left = self.nameRawNode(node.left.?);
                copy.right = self.nameRawNode(node.right.?);
                return self.arena.create(ZigAstNode, copy);
            },
            .unary_op, .member => {
                var copy = node.*;
                copy.left = self.nameRawNode(node.left.?);
                return self.arena.create(ZigAstNode, copy);
            },
            .ternary => {
                var copy = node.*;
                copy.left = self.nameRawNode(node.left.?);
                copy.right = self.nameRawNode(node.right.?);
                copy.third = self.nameRawNode(node.third.?);
                return self.arena.create(ZigAstNode, copy);
            },
            else => return @constCast(node),
        }
    }

    pub fn materializeExpr(self: *Materializer, node: *const ZigAstNode) *ZigAstNode {
        return self.materializeExprInternal(node, &[_][]const u8{});
    }

    pub fn materializeExprInternal(
        self: *Materializer,
        node: *const ZigAstNode,
        scoped_refs: []const []const u8,
    ) *ZigAstNode {
        if (!node.has_ref_or_comp) return @constCast(node);

        switch (node.kind) {
            .ref => {
                for (scoped_refs) |sr| {
                    if (std.mem.eql(u8, sr, node.str_val)) return @constCast(node);
                }
                const res = self.resolveRef(node.str_val, true);
                return if (res == .ast_val) res.ast_val else matValToLiteralAst(self.arena, res);
            },
            .comp => {
                const h = fnv1a32(node.str_val);
                const is_rt = self.isRuntimeCall(h, node.str_val);
                if (node.is_fn and !is_rt) {
                    self.pushUnknownFunction(node.str_val);
                    return self.arena.create(ZigAstNode, .{ .kind = .null_node });
                }
                if (self.materializeLazyBuiltin(node, scoped_refs)) |lazy_node| {
                    return lazy_node;
                }
                if (is_rt) {
                    return self.materializeCall(node, true, scoped_refs);
                } else {
                    var rec_args = self.arena.alloc(*ZigAstNode, node.args.len);
                    for (node.args, 0..) |a, i| {
                        rec_args[i] = self.materializeExprInternal(a, scoped_refs);
                    }
                    var copy = node.*;
                    copy.args = rec_args;
                    if (self.schema.findComponent(h, node.str_val)) |comp_def| {
                        copy.mapped_props = self.nameArgs(rec_args, comp_def.params);
                    } else {
                        self.pushUnknownComponent(node.str_val);
                    }
                    return self.arena.create(ZigAstNode, copy);
                }
            },
            .arr => {
                var new_els = self.arena.alloc(*ZigAstNode, node.args.len);
                for (node.args, 0..) |e, i| new_els[i] = self.materializeExprInternal(e, scoped_refs);
                var copy = node.*;
                copy.args = new_els;
                return self.arena.create(ZigAstNode, copy);
            },
            .obj => {
                var new_entries = self.arena.alloc(ZigAstObjEntry, node.obj_entries.len);
                for (node.obj_entries, 0..) |e, i| {
                    new_entries[i] = .{ .key = e.key, .val = self.materializeExprInternal(e.val, scoped_refs) };
                }
                var copy = node.*;
                copy.obj_entries = new_entries;
                return self.arena.create(ZigAstNode, copy);
            },
            .bin_op, .index => {
                const nl = self.materializeExprInternal(node.left.?, scoped_refs);
                const nr = self.materializeExprInternal(node.right.?, scoped_refs);
                if (nl == node.left.? and nr == node.right.?) return @constCast(node);
                var copy = node.*;
                copy.left = nl;
                copy.right = nr;
                return self.arena.create(ZigAstNode, copy);
            },
            .unary_op, .member, .assign => {
                const nl = self.materializeExprInternal(node.left.?, scoped_refs);
                if (nl == node.left.?) return @constCast(node);
                var copy = node.*;
                copy.left = nl;
                return self.arena.create(ZigAstNode, copy);
            },
            .ternary => {
                const nc = self.materializeExprInternal(node.left.?, scoped_refs);
                const nt = self.materializeExprInternal(node.right.?, scoped_refs);
                const ne = self.materializeExprInternal(node.third.?, scoped_refs);
                if (nc == node.left.? and nt == node.right.? and ne == node.third.?) return @constCast(node);
                var copy = node.*;
                copy.left = nc;
                copy.right = nt;
                copy.third = ne;
                return self.arena.create(ZigAstNode, copy);
            },
            else => return @constCast(node),
        }
    }

    pub fn materializeLazyBuiltin(
        self: *Materializer,
        node: *const ZigAstNode,
        scoped_refs: []const []const u8,
    ) ?*ZigAstNode {
        if (node.args.len < 3) return null;
        const h = fnv1a32(node.str_val);
        const def_info = self.schema.findCallDef(h, node.str_val) orelse return null;
        if (def_info.is_action or !def_info.is_lazy) return null;

        const var_arg = node.args[1];
        const var_name: []const u8 = switch (var_arg.kind) {
            .ref, .str => var_arg.str_val,
            else => return null,
        };
        if (var_name.len == 0) return null;

        var next_scoped = self.arena.alloc([]const u8, scoped_refs.len + 1);
        if (scoped_refs.len > 0) @memcpy(next_scoped[0..scoped_refs.len], scoped_refs);
        next_scoped[scoped_refs.len] = var_name;

        var new_args = self.arena.alloc(*ZigAstNode, node.args.len);
        for (node.args, 0..) |a, i| {
            new_args[i] = if (i == 1) a else self.materializeExprInternal(a, next_scoped);
        }
        var copy = node.*;
        copy.args = new_args;
        return self.arena.create(ZigAstNode, copy);
    }

    pub fn materializeCall(
        self: *Materializer,
        node: *const ZigAstNode,
        in_expr: bool,
        scoped_refs: []const []const u8,
    ) *ZigAstNode {
        var new_args = self.arena.alloc(*ZigAstNode, node.args.len);
        for (node.args, 0..) |a, i| {
            new_args[i] = if (in_expr) self.materializeExprInternal(a, scoped_refs) else self.materializeExpr(a);
        }

        const h = fnv1a32(node.str_val);
        const def_info = self.schema.findCallDef(h, node.str_val);
        if (def_info == null or def_info.?.is_lazy) {
            var copy = node.*;
            copy.args = new_args;
            return self.arena.create(ZigAstNode, copy);
        }

        const info = def_info.?;
        const mapped_props = if (info.is_builtin)
            self.nameArgs(new_args, info.params)
        else
            self.mapCallArgs(node.str_val, new_args, info);

        if (mapped_props) |mp| {
            var copy = node.*;
            copy.args = new_args;
            copy.mapped_props = mp;
            return self.arena.create(ZigAstNode, copy);
        } else if (info.is_action) {
            const empty_arr = self.arena.create(ZigAstNode, .{ .kind = .arr, .args = &[_]*ZigAstNode{} });
            var act_args = self.arena.alloc(*ZigAstNode, 1);
            act_args[0] = empty_arr;
            return self.arena.create(ZigAstNode, .{ .kind = .comp, .str_val = "Action", .args = act_args });
        } else {
            return self.arena.create(ZigAstNode, .{ .kind = .null_node });
        }
    }

    pub fn materializeValue(self: *Materializer, node: *const ZigAstNode) ZigMatVal {
        switch (node.kind) {
            .ref => return self.resolveRef(node.str_val, false),
            .str => return .{ .str_val = node.str_val },
            .num_int => return .{ .int_val = node.int_val },
            .num_float => return .{ .float_val = node.float_val },
            .bool_node => return .{ .bool_val = node.bool_val },
            .null_node, .ph => return .null_val,
            .arr => {
                var items = Vec(ZigMatVal).init(self.arena, node.args.len);
                for (node.args) |el| {
                    if (el.kind == .ref) {
                        const val = self.resolveRef(el.str_val, false);
                        if (val != .null_val) items.append(val);
                    } else if (el.kind == .ph) {
                        // Omit placeholder
                    } else {
                        const val = self.materializeValue(el);
                        if (val == .null_val and el.kind == .comp) {
                            // Omit failed component in array
                        } else {
                            items.append(val);
                        }
                    }
                }
                return .{ .arr_val = items.items };
            },
            .obj => {
                var entries = Vec(ZigMatEntry).init(self.arena, node.obj_entries.len);
                for (node.obj_entries) |e| {
                    const val = self.materializeValue(e.val);
                    var found: ?usize = null;
                    for (entries.items, 0..) |existing, i| {
                        if (std.mem.eql(u8, existing.key, e.key)) {
                            found = i;
                            break;
                        }
                    }
                    if (found) |fi| {
                        entries.items[fi].val = val;
                    } else {
                        entries.append(.{ .key = e.key, .val = val });
                    }
                }
                const obj = self.arena.create(ZigMatObj, .{ .entries = entries.items, .has_keys_meta = true });
                return .{ .obj_val = obj };
            },
            .comp => {
                const h = fnv1a32(node.str_val);
                const is_rt = self.isRuntimeCall(h, node.str_val);
                if (node.is_fn and !is_rt) {
                    self.pushUnknownFunction(node.str_val);
                    return .null_val;
                }
                if (isReservedCall(node.str_val)) {
                    self.pushInlineReserved(node.str_val);
                    return .null_val;
                }
                if (is_rt) {
                    if (self.materializeLazyBuiltin(node, &[_][]const u8{})) |lazy_node| {
                        return .{ .ast_val = lazy_node };
                    }
                    return .{ .ast_val = self.materializeCall(node, false, &[_][]const u8{}) };
                }
                if (self.schema.findComponent(h, node.str_val)) |comp_def| {
                    return self.materializeComponent(node.str_val, node.args, comp_def);
                } else {
                    self.pushUnknownComponent(node.str_val);
                    return .null_val;
                }
            },
            else => {
                return .{ .ast_val = self.materializeExpr(node) };
            },
        }
    }

    pub fn materializeComponent(
        self: *Materializer,
        name: []const u8,
        args: []const *ZigAstNode,
        comp_def: *const CompDef,
    ) ZigMatVal {
        const params = comp_def.params;
        var props = Vec(ZigMatEntry).init(self.arena, params.len);
        var has_dynamic = false;
        var drop_component = false;
        const MissingIssue = struct { is_null: bool, path: []const u8 };
        var missing = Vec(MissingIssue).init(self.arena, 4);

        const pair_cnt = @min(params.len, args.len);
        for (0..pair_cnt) |i| {
            const param = &params[i];
            var val = self.materializeValue(args[i]);
            var keep = true;

            if (param.has_schema) {
                const res = self.validateSchemaValue(val, &param.schema, name, param.path);
                if (res.valid) {
                    val = res.val;
                } else {
                    if (param.has_default) {
                        val = defaultValToMatVal(self.arena, param.default_val);
                    } else if (!param.required) {
                        keep = false;
                    } else {
                        drop_component = true;
                    }
                }
            }

            if (keep) {
                if (val == .null_val and param.required) {
                    if (param.has_default) {
                        const def_mat = defaultValToMatVal(self.arena, param.default_val);
                        props.append(.{ .key = param.name, .val = def_mat });
                        if (!has_dynamic and containsDynamicValue(def_mat)) has_dynamic = true;
                    } else {
                        props.append(.{ .key = param.name, .val = .null_val });
                        missing.append(.{ .is_null = true, .path = param.path });
                    }
                } else {
                    props.append(.{ .key = param.name, .val = val });
                    if (!has_dynamic and containsDynamicValue(val)) has_dynamic = true;
                }
            }
        }

        if (args.len < params.len) {
            for (params[args.len..]) |*param| {
                if (param.required) {
                    if (param.has_default) {
                        const def_mat = defaultValToMatVal(self.arena, param.default_val);
                        props.append(.{ .key = param.name, .val = def_mat });
                        if (!has_dynamic and containsDynamicValue(def_mat)) has_dynamic = true;
                    } else {
                        missing.append(.{ .is_null = false, .path = param.path });
                    }
                }
            }
        } else if (args.len > params.len) {
            self.pushExcessArgs(name, params.len, args.len);
        }

        if (missing.items.len > 0) {
            for (missing.items) |m| {
                self.pushMissingOrNullRequired(m.is_null, name, m.path, comp_def.signature);
            }
            return .null_val;
        }
        if (drop_component) return .null_val;

        const el = self.arena.create(ZigElementNode, .{
            .type_name = name,
            .props = props.items,
            .partial = self.partial,
            .has_dynamic_props = has_dynamic,
        });
        return .{ .element_val = el };
    }

    pub fn resolveRef(self: *Materializer, name: []const u8, mode_is_expr: bool) ZigMatVal {
        const h = fnv1a32(name);
        const stmt_idx = self.findStmtIdx(h, name) orelse {
            self.unres.append(name);
            return if (mode_is_expr)
                .{ .ast_val = self.arena.create(ZigAstNode, .{ .kind = .ph, .str_val = name }) }
            else
                .null_val;
        };

        if (self.visited[stmt_idx]) {
            self.unres.append(name);
            return if (mode_is_expr)
                .{ .ast_val = self.arena.create(ZigAstNode, .{ .kind = .ph, .str_val = name }) }
            else
                .null_val;
        }

        const stmt = &self.stmts[stmt_idx];

        // Check native + BEAM cache when resolving value in streaming mode
        if (!mode_is_expr and self.stream != null and !stmt.is_pending) {
            const cstmt = &self.stream.?.completed_stmts.items[stmt.completed_idx];
            const slot = &cstmt.slots[@intFromBool(self.partial)];
            if (slot.valid) {
                self.unreached[stmt_idx] = false;
                for (slot.sub_reached) |sub_idx| {
                    if (sub_idx < self.unreached.len) self.unreached[sub_idx] = false;
                }
                if (slot.errors.len > 0) {
                    self.errors.appendSlice(slot.errors);
                }
                return slot.val;
            }
        }

        self.unreached[stmt_idx] = false;

        if (stmt.expr.kind == .comp and !stmt.expr.is_fn and isReservedCall(stmt.expr.str_val)) {
            const is_mut = std.mem.eql(u8, stmt.expr.str_val, "Mutation");
            return .{
                .ast_val = self.arena.create(ZigAstNode, .{
                    .kind = .runtime_ref,
                    .str_val = name,
                    .bool_val = is_mut,
                }),
            };
        }

        const prev_id = self.current_statement_id;
        const prev_has = self.has_current_id;
        const prev_in_pending = self.in_pending;
        const prev_lenient = self.used_partial_lenient;
        const now_in_pending = prev_in_pending or stmt.is_pending;
        const can_cache = (!mode_is_expr and self.stream != null and !now_in_pending);

        const err_start = self.errors.items.len;
        const unres_start = self.unres.items.len;
        const prev_unr = if (can_cache) self.arena.dupe(bool, self.unreached) else &[_]bool{};

        self.visited[stmt_idx] = true;
        self.current_statement_id = name;
        self.has_current_id = true;
        self.in_pending = now_in_pending;
        self.used_partial_lenient = false;

        var res_val: ZigMatVal = if (!mode_is_expr)
            self.materializeValue(stmt.expr)
        else
            .{ .ast_val = self.materializeExpr(stmt.expr) };

        const stmt_lenient = self.used_partial_lenient;
        self.visited[stmt_idx] = false;
        self.current_statement_id = prev_id;
        self.has_current_id = prev_has;
        self.in_pending = prev_in_pending;
        self.used_partial_lenient = prev_lenient or stmt_lenient;

        if (!mode_is_expr and res_val == .element_val) {
            var copy_el = res_val.element_val.*;
            copy_el.statement_id = name;
            copy_el.beam_cache_key = 0;
            res_val = .{ .element_val = self.arena.create(ZigElementNode, copy_el) };
        }

        if (can_cache and self.unres.items.len == unres_start) {
            var reached_pending = false;
            var sub_reached_vec = Vec(u32).init(self.arena, 8);
            for (0..self.stmts.len) |i| {
                if (prev_unr[i] and !self.unreached[i]) {
                    if (self.stmts[i].is_pending) {
                        reached_pending = true;
                        break;
                    }
                    sub_reached_vec.append(@intCast(i));
                }
            }

            if (!reached_pending) {
                var stream_ptr = self.stream.?;
                const s_arena = &stream_ptr.stmt_arena;
                var cstmt = &stream_ptr.completed_stmts.items[stmt.completed_idx];
                const slot_idx: usize = if (stmt_lenient) @intFromBool(self.partial) else 0;
                const int_key: i64 = ((@as(i64, @intCast(stmt.completed_idx)) + 1) << 1) | @as(i64, @intCast(slot_idx));

                if (res_val == .element_val) {
                    const el_term = elementToTerm(self.env, self.arena, res_val.element_val, self.beam_mat_cache);
                    var next_map: ERL_NIF_TERM = 0;
                    if (nif_make_map_put(self.env, self.beam_mat_cache, nif_make_int64(self.env, int_key), el_term, &next_map) != 0) {
                        self.beam_mat_cache = next_map;
                        res_val.element_val.beam_cache_key = int_key;
                    }
                }

                const cloned_val = cloneMatValToArena(s_arena, res_val);
                const sub_errs = self.errors.items[err_start..];
                var cerrs: []ValidationError = &[_]ValidationError{};
                if (sub_errs.len > 0) {
                    cerrs = s_arena.alloc(ValidationError, sub_errs.len);
                    for (sub_errs, 0..) |*e, i| {
                        const err_key: i64 = -((int_key << 8) | @as(i64, @intCast(i + 1)));
                        const err_term = validationErrorToTerm(self.env, e.*, self.beam_mat_cache);
                        var next_map: ERL_NIF_TERM = 0;
                        if (nif_make_map_put(self.env, self.beam_mat_cache, nif_make_int64(self.env, err_key), err_term, &next_map) != 0) {
                            self.beam_mat_cache = next_map;
                            e.beam_cache_key = err_key;
                        }
                        cerrs[i] = .{
                            .code = s_arena.dupe(u8, e.code),
                            .component = s_arena.dupe(u8, e.component),
                            .path = s_arena.dupe(u8, e.path),
                            .message = s_arena.dupe(u8, e.message),
                            .statement_id = s_arena.dupe(u8, e.statement_id),
                            .has_statement_id = e.has_statement_id,
                            .is_warning = e.is_warning,
                            .beam_cache_key = e.beam_cache_key,
                        };
                    }
                }
                const cloned_sub = s_arena.dupe(u32, sub_reached_vec.items);
                const new_slot = StmtCacheSlot{
                    .valid = true,
                    .val = cloned_val,
                    .errors = cerrs,
                    .sub_reached = cloned_sub,
                };
                if (!stmt_lenient) {
                    cstmt.slots[0] = new_slot;
                    cstmt.slots[1] = new_slot;
                } else {
                    cstmt.slots[slot_idx] = new_slot;
                }
            }
        }

        return res_val;
    }
};

fn emptyResultTerm(env: ?*ErlNifEnv, incomplete: bool) ERL_NIF_TERM {
    const empty_list = makeList(env, &[_]ERL_NIF_TERM{});
    const empty_map = nif_make_new_map(env);

    var meta_keys = [_]ERL_NIF_TERM{ A.incomplete, A.unresolved, A.orphaned, A.statement_count, A.errors };
    var meta_vals = [_]ERL_NIF_TERM{
        if (incomplete) A.true_atom else A.false_atom,
        empty_list,
        empty_list,
        nif_make_int64(env, 0),
        empty_list,
    };
    const meta_map = makeMap(env, &meta_keys, &meta_vals);

    var res_keys = [_]ERL_NIF_TERM{ A.root, A.meta, A.state_declarations, A.query_statements, A.mutation_statements };
    var res_vals = [_]ERL_NIF_TERM{ A.nil_atom, meta_map, empty_map, empty_list, empty_list };
    return makeMap(env, &res_keys, &res_vals);
}

fn resolvesToComponentCallNative(mat: *const Materializer, start_idx: usize) bool {
    var cur_idx: ?usize = start_idx;
    var depth: usize = 0;
    while (cur_idx != null and depth < 64) : (depth += 1) {
        const expr = mat.stmts[cur_idx.?].expr;
        if (expr.kind == .ref) {
            const h = fnv1a32(expr.str_val);
            cur_idx = mat.findStmtIdx(h, expr.str_val);
        } else {
            return isComponentCallNode(expr);
        }
    }
    return false;
}

fn buildResultNative(
    env: ?*ErlNifEnv,
    arena: *BumpArena,
    schema: *const ZigSchema,
    stmts: []const ActiveStmt,
    was_incomplete: bool,
    stmt_count: usize,
    root_name: []const u8,
    partial_tail_name: ?[]const u8,
    stream: ?*ZigStreamResource,
    beam_mat_cache_in: ERL_NIF_TERM,
) struct { res_term: ERL_NIF_TERM, beam_mat_cache_out: ERL_NIF_TERM } {
    const default_root_hash = comptime fnv1a32("root");
    var entry_idx: ?usize = null;
    var entry_fallback = false;

    var stmt_buckets = [_]i32{-1} ** 256;
    var stmt_next = arena.alloc(i32, stmts.len);
    for (stmts, 0..) |*s, i| {
        const b = s.id_hash & 255;
        stmt_next[i] = stmt_buckets[b];
        stmt_buckets[b] = @intCast(i);
        if (entry_idx == null and s.id_hash == default_root_hash and std.mem.eql(u8, s.id, "root")) {
            entry_idx = i;
            entry_fallback = false;
        }
    }
    if (entry_idx == null and root_name.len > 0) {
        for (stmts, 0..) |*s, i| {
            if (s.kind == .value and isComponentCallNode(s.expr) and std.mem.eql(u8, s.expr.str_val, root_name)) {
                entry_idx = i;
                entry_fallback = true;
                break;
            }
        }
    }

    const visited = arena.alloc(bool, stmts.len);
    @memset(visited, false);
    const unreached = arena.alloc(bool, stmts.len);
    for (stmts, 0..) |*s, i| {
        if (entry_idx != null and entry_idx.? == i) {
            unreached[i] = false;
        } else if (s.kind == .state or s.kind == .query or s.kind == .mutation) {
            unreached[i] = false;
        } else {
            unreached[i] = true;
        }
    }

    const entry_is_transient = (entry_idx == null) or entry_fallback or stmts[entry_idx.?].is_pending;

    var mat = Materializer{
        .env = env,
        .arena = arena,
        .schema = schema,
        .stmts = stmts,
        .stmt_buckets = stmt_buckets,
        .stmt_next = stmt_next,
        .stream = stream,
        .beam_mat_cache = beam_mat_cache_in,
        .partial = was_incomplete,
        .current_statement_id = if (entry_idx) |ei| stmts[ei].id else "",
        .has_current_id = (entry_idx != null),
        .in_pending = entry_is_transient,
        .visited = visited,
        .unreached = unreached,
        .errors = Vec(ValidationError).init(arena, 8),
        .unres = Vec([]const u8).init(arena, 8),
    };

    var root_term: ERL_NIF_TERM = A.nil_atom;
    var has_root = false;
    var root_expr_term: ERL_NIF_TERM = 0;
    var has_root_expr = false;

    if (entry_idx) |ei| {
        const entry_stmt = &stmts[ei];
        const mat_val = mat.materializeValue(entry_stmt.expr);
        if (mat_val == .element_val) {
            var copy_el = mat_val.element_val.*;
            copy_el.statement_id = entry_stmt.id;
            copy_el.beam_cache_key = 0;
            root_term = elementToTerm(env, arena, &copy_el, mat.beam_mat_cache);
            has_root = true;
        } else if (mat_val == .ast_val and containsComponentAst(mat_val.ast_val)) {
            root_expr_term = astToTerm(env, arena, mat_val.ast_val);
            has_root_expr = true;
        }
    }

    // Extract state_declarations, query_statements, mutation_statements
    var state_keys = Vec(ERL_NIF_TERM).init(arena, 16);
    var state_vals = Vec(ERL_NIF_TERM).init(arena, 16);
    var state_names = Vec([]const u8).init(arena, 16);
    var query_terms = Vec(ERL_NIF_TERM).init(arena, 8);
    var mutation_terms = Vec(ERL_NIF_TERM).init(arena, 8);

    for (stmts) |*s| {
        switch (s.kind) {
            .state => {
                const prev_in_p = mat.in_pending;
                mat.in_pending = prev_in_p or s.is_pending;
                const val = mat.materializeValue(s.expr);
                mat.in_pending = prev_in_p;
                const val_term = matValToTerm(env, arena, val, false, mat.beam_mat_cache);

                var found: ?usize = null;
                for (state_names.items, 0..) |existing, i| {
                    if (std.mem.eql(u8, existing, s.id)) {
                        found = i;
                        break;
                    }
                }
                if (found) |fi| {
                    state_vals.items[fi] = val_term;
                } else {
                    state_names.append(s.id);
                    state_keys.append(makeBin(env, s.id));
                    state_vals.append(val_term);
                }
            },
            .query => {
                const named_args = mat.nameRawCallArgs(s.expr.args, s.id);
                const tool_term = if (named_args.len > 0) astToTerm(env, arena, named_args[0]) else A.nil_atom;
                const args_term = if (named_args.len > 1) astToTerm(env, arena, named_args[1]) else A.nil_atom;
                const defs_term = if (named_args.len > 2) astToTerm(env, arena, named_args[2]) else A.nil_atom;
                const refr_term = if (named_args.len > 3) astToTerm(env, arena, named_args[3]) else A.nil_atom;
                const deps_term = if (s.deps.len > 0) slicesToTermList(env, arena, s.deps) else A.nil_atom;

                var q_keys = [_]ERL_NIF_TERM{
                    A.statement_id,
                    A.tool_ast,
                    A.args_ast,
                    A.defaults_ast,
                    A.refresh_ast,
                    A.deps,
                    A.complete,
                };
                var q_vals = [_]ERL_NIF_TERM{
                    makeBin(env, s.id),
                    tool_term,
                    args_term,
                    defs_term,
                    refr_term,
                    deps_term,
                    A.true_atom,
                };
                query_terms.append(makeMap(env, &q_keys, &q_vals));
            },
            .mutation => {
                const named_args = mat.nameRawCallArgs(s.expr.args, s.id);
                const tool_term = if (named_args.len > 0) astToTerm(env, arena, named_args[0]) else A.nil_atom;
                const args_term = if (named_args.len > 1) astToTerm(env, arena, named_args[1]) else A.nil_atom;

                var m_keys = [_]ERL_NIF_TERM{ A.statement_id, A.tool_ast, A.args_ast };
                var m_vals = [_]ERL_NIF_TERM{ makeBin(env, s.id), tool_term, args_term };
                mutation_terms.append(makeMap(env, &m_keys, &m_vals));
            },
            .value => {},
        }
    }

    // Add implicit state_refs with nil value
    for (stmts) |*s| {
        for (s.state_refs) |dep| {
            const skip = (partial_tail_name != null) and s.is_pending and std.mem.eql(u8, dep, partial_tail_name.?);
            if (!skip) {
                var exists = false;
                for (state_names.items) |existing| {
                    if (std.mem.eql(u8, existing, dep)) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    state_names.append(dep);
                    state_keys.append(makeBin(env, dep));
                    state_vals.append(A.nil_atom);
                }
            }
        }
    }

    // Check no-root validation issue
    mat.current_statement_id = if (entry_idx) |ei| stmts[ei].id else "";
    mat.has_current_id = (entry_idx != null);

    if (entry_idx == null) {
        mat.pushNoRoot(root_name, 0);
    } else if (!has_root and !has_root_expr and !resolvesToComponentCallNative(&mat, entry_idx.?)) {
        mat.pushNoRoot(root_name, 1);
    } else if (entry_fallback) {
        mat.pushNoRoot(root_name, if (has_root) 2 else 0);
    }

    // Collect orphaned statements in forward statement order
    var orphan_terms = Vec(ERL_NIF_TERM).init(arena, 8);
    if (entry_idx != null) {
        for (stmts, 0..) |*s, i| {
            if (mat.unreached[i]) {
                orphan_terms.append(makeBin(env, s.id));
            }
        }
    }

    // Build errors list
    var err_terms = arena.alloc(ERL_NIF_TERM, mat.errors.items.len);
    for (mat.errors.items, 0..) |e, i| {
        err_terms[i] = validationErrorToTerm(env, e, mat.beam_mat_cache);
    }

    var meta_keys = [_]ERL_NIF_TERM{ A.incomplete, A.unresolved, A.orphaned, A.statement_count, A.errors };
    var meta_vals = [_]ERL_NIF_TERM{
        if (was_incomplete) A.true_atom else A.false_atom,
        slicesToTermList(env, arena, mat.unres.items),
        makeList(env, orphan_terms.items),
        nif_make_int64(env, @intCast(stmt_count)),
        makeList(env, err_terms),
    };
    const meta_map = makeMap(env, &meta_keys, &meta_vals);

    var res_keys: [6]ERL_NIF_TERM = undefined;
    var res_vals: [6]ERL_NIF_TERM = undefined;
    res_keys[0] = A.root;
    res_vals[0] = root_term;
    res_keys[1] = A.meta;
    res_vals[1] = meta_map;
    res_keys[2] = A.state_declarations;
    res_vals[2] = makeMap(env, state_keys.items, state_vals.items);
    res_keys[3] = A.query_statements;
    res_vals[3] = makeList(env, query_terms.items);
    res_keys[4] = A.mutation_statements;
    res_vals[4] = makeList(env, mutation_terms.items);
    var rcnt: usize = 5;

    if (has_root_expr) {
        res_keys[rcnt] = A.root_expression;
        res_vals[rcnt] = root_expr_term;
        rcnt += 1;
    }

    return .{
        .res_term = makeMap(env, res_keys[0..rcnt], res_vals[0..rcnt]),
        .beam_mat_cache_out = mat.beam_mat_cache,
    };
}

fn computeStreamResult(
    env: ?*ErlNifEnv,
    stream: *ZigStreamResource,
    complete: bool,
    beam_mat_cache_in: ERL_NIF_TERM,
) ERL_NIF_TERM {
    var stack_buf: [65536]u8 align(16) = undefined;
    var temp_arena = BumpArena.init(&stack_buf);
    defer temp_arena.deinit();

    var beam_cache = beam_mat_cache_in;
    const pending_text = stream.advanceStream(env, &temp_arena, &beam_cache);

    const completed_items = stream.completed_stmts.items;
    const root_name = if (stream.rootName().len > 0) stream.rootName() else stream.schema.root;

    if (pending_text.len == 0) {
        if (stream.completed_count == 0) {
            return nif_make_tuple2(env, emptyResultTerm(env, true), beam_cache);
        }
        var active = temp_arena.alloc(ActiveStmt, completed_items.len);
        for (completed_items, 0..) |*c, i| {
            active[i] = .{
                .id = c.id,
                .id_hash = c.id_hash,
                .kind = c.kind,
                .expr = c.expr,
                .state_refs = c.state_refs,
                .deps = c.deps,
                .is_pending = false,
                .completed_idx = @intCast(i),
            };
        }
        const out = buildResultNative(
            env,
            &temp_arena,
            stream.schema,
            active,
            false,
            stream.completed_count,
            root_name,
            null,
            stream,
            beam_cache,
        );
        return nif_make_tuple2(env, out.res_term, out.beam_mat_cache_out);
    } else {
        const ac = autoCloseSlice(&temp_arena, pending_text);
        const pending_stmts = parseStatementsToNative(&temp_arena, ac.text, false);
        if (pending_stmts.len == 0) {
            if (stream.completed_count == 0) {
                return nif_make_tuple2(env, emptyResultTerm(env, ac.was_incomplete), beam_cache);
            }
            var active = temp_arena.alloc(ActiveStmt, completed_items.len);
            for (completed_items, 0..) |*c, i| {
                active[i] = .{
                    .id = c.id,
                    .id_hash = c.id_hash,
                    .kind = c.kind,
                    .expr = c.expr,
                    .state_refs = c.state_refs,
                    .deps = c.deps,
                    .is_pending = false,
                    .completed_idx = @intCast(i),
                };
            }
            const out = buildResultNative(
                env,
                &temp_arena,
                stream.schema,
                active,
                ac.was_incomplete,
                stream.completed_count,
                root_name,
                null,
                stream,
                beam_cache,
            );
            return nif_make_tuple2(env, out.res_term, out.beam_mat_cache_out);
        } else {
            var active_vec = Vec(ActiveStmt).init(&temp_arena, completed_items.len + pending_stmts.len);
            for (completed_items, 0..) |*c, i| {
                active_vec.append(.{
                    .id = c.id,
                    .id_hash = c.id_hash,
                    .kind = c.kind,
                    .expr = c.expr,
                    .state_refs = c.state_refs,
                    .deps = c.deps,
                    .is_pending = false,
                    .completed_idx = @intCast(i),
                });
            }

            var pending_overwrote = false;
            for (pending_stmts) |p| {
                const existing_comp_idx = stream.findCompletedIdx(p.id_hash, p.id);
                if (existing_comp_idx != null and ac.was_incomplete) {
                    continue;
                }
                var found_active: ?usize = null;
                if (existing_comp_idx) |ci| {
                    found_active = @intCast(ci);
                } else {
                    for (active_vec.items[completed_items.len..], completed_items.len..) |*a, ai| {
                        if (a.id_hash == p.id_hash and std.mem.eql(u8, a.id, p.id)) {
                            found_active = ai;
                            break;
                        }
                    }
                }
                if (found_active) |ai| {
                    if (existing_comp_idx != null) pending_overwrote = true;
                    active_vec.items[ai] = .{
                        .id = p.id,
                        .id_hash = p.id_hash,
                        .kind = p.kind,
                        .expr = p.expr,
                        .state_refs = p.state_refs,
                        .deps = p.deps,
                        .is_pending = true,
                        .completed_idx = 0,
                    };
                } else {
                    active_vec.append(.{
                        .id = p.id,
                        .id_hash = p.id_hash,
                        .kind = p.kind,
                        .expr = p.expr,
                        .state_refs = p.state_refs,
                        .deps = p.deps,
                        .is_pending = true,
                        .completed_idx = 0,
                    });
                }
            }

            if (pending_overwrote) {
                stream.clearAllSlots();
                beam_cache = nif_make_new_map(env);
            }

            const tail_name = detectPartialStateTailNative(stream.bufSlice(), pending_text, complete);
            const out = buildResultNative(
                env,
                &temp_arena,
                stream.schema,
                active_vec.items,
                ac.was_incomplete,
                stream.completed_count + pending_stmts.len,
                root_name,
                tail_name,
                stream,
                beam_cache,
            );
            return nif_make_tuple2(env, out.res_term, out.beam_mat_cache_out);
        }
    }
}

export fn zig_parse_and_materialize(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 4) return nif_make_badarg(env);
    const input = inspectArgBin(env, argv[0]) orelse return nif_make_badarg(env);
    var schema_id: c_uint = 0;
    if (nif_get_uint(env, argv[1], &schema_id) == 0) return nif_make_badarg(env);
    const schema_bin = inspectArgBin(env, argv[2]) orelse return nif_make_badarg(env);
    const root_arg = inspectArgBin(env, argv[3]) orelse return nif_make_badarg(env);

    var stack_buf: [65536]u8 align(16) = undefined;
    var arena = BumpArena.init(&stack_buf);
    defer arena.deinit();

    const trimmed = preprocessSlice(&arena, input);
    if (trimmed.len == 0) {
        return emptyResultTerm(env, true);
    }

    const ac = autoCloseSlice(&arena, trimmed);
    const parsed_stmts = parseStatementsToNative(&arena, ac.text, false);
    if (parsed_stmts.len == 0) {
        return emptyResultTerm(env, ac.was_incomplete);
    }

    // Deduplicate statements (first position wins in order, last definition wins in value)
    var active = Vec(ActiveStmt).init(&arena, parsed_stmts.len);
    for (parsed_stmts) |p| {
        var found: ?usize = null;
        for (active.items, 0..) |*a, i| {
            if (a.id_hash == p.id_hash and std.mem.eql(u8, a.id, p.id)) {
                found = i;
                break;
            }
        }
        if (found) |fi| {
            active.items[fi] = .{
                .id = p.id,
                .id_hash = p.id_hash,
                .kind = p.kind,
                .expr = p.expr,
                .state_refs = p.state_refs,
                .deps = p.deps,
                .is_pending = false,
                .completed_idx = 0,
            };
        } else {
            active.append(.{
                .id = p.id,
                .id_hash = p.id_hash,
                .kind = p.kind,
                .expr = p.expr,
                .state_refs = p.state_refs,
                .deps = p.deps,
                .is_pending = false,
                .completed_idx = 0,
            });
        }
    }

    const schema = getOrDecodeSchema(@intCast(schema_id), schema_bin);
    const root_name = if (root_arg.len > 0) root_arg else schema.root;
    const out = buildResultNative(
        env,
        &arena,
        schema,
        active.items,
        ac.was_incomplete,
        active.items.len,
        root_name,
        null,
        null,
        0,
    );
    return out.res_term;
}

export fn zig_stream_new(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 3) return nif_make_badarg(env);
    var schema_id: c_uint = 0;
    if (nif_get_uint(env, argv[0], &schema_id) == 0) return nif_make_badarg(env);
    const schema_bin = inspectArgBin(env, argv[1]) orelse return nif_make_badarg(env);
    const root_arg = inspectArgBin(env, argv[2]) orelse return nif_make_badarg(env);

    const schema = getOrDecodeSchema(@intCast(schema_id), schema_bin);
    const raw_res = nif_alloc_resource(STREAM_RESOURCE_TYPE, @sizeOf(ZigStreamResource)) orelse return nif_make_badarg(env);
    const stream: *ZigStreamResource = @ptrCast(@alignCast(raw_res));

    var r_ptr: ?[*]u8 = null;
    if (root_arg.len > 0) {
        r_ptr = nif_alloc(root_arg.len);
        if (r_ptr != null) @memcpy(r_ptr.?[0..root_arg.len], root_arg);
    }

    stream.* = .{
        .schema = schema,
        .root_name_ptr = r_ptr,
        .root_name_len = if (r_ptr != null) root_arg.len else 0,
        .stmt_arena = BumpArena.init(&[_]u8{}),
        .completed_stmts = undefined,
    };
    stream.completed_stmts = Vec(CompletedStmt).init(&stream.stmt_arena, 32);

    const term = nif_make_resource(env, raw_res);
    nif_release_resource(raw_res);
    return term;
}

export fn zig_stream_reset(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 1) return nif_make_badarg(env);
    var raw_res: ?*anyopaque = null;
    if (nif_get_resource(env, argv[0], STREAM_RESOURCE_TYPE, &raw_res) == 0 or raw_res == null) {
        return nif_make_badarg(env);
    }
    const stream: *ZigStreamResource = @ptrCast(@alignCast(raw_res.?));
    stream.resetFull();
    return A.ok;
}

export fn zig_stream_push(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 4) return nif_make_badarg(env);
    var raw_res: ?*anyopaque = null;
    if (nif_get_resource(env, argv[0], STREAM_RESOURCE_TYPE, &raw_res) == 0 or raw_res == null) {
        return nif_make_badarg(env);
    }
    const chunk = inspectArgBin(env, argv[1]) orelse return nif_make_badarg(env);
    var complete_int: c_int = 0;
    _ = nif_get_int(env, argv[2], &complete_int);
    const beam_mat_cache = argv[3];

    const stream: *ZigStreamResource = @ptrCast(@alignCast(raw_res.?));
    stream.appendChunk(chunk);
    return computeStreamResult(env, stream, complete_int != 0, beam_mat_cache);
}

export fn zig_stream_set(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 4) return nif_make_badarg(env);
    var raw_res: ?*anyopaque = null;
    if (nif_get_resource(env, argv[0], STREAM_RESOURCE_TYPE, &raw_res) == 0 or raw_res == null) {
        return nif_make_badarg(env);
    }
    const full_text = inspectArgBin(env, argv[1]) orelse return nif_make_badarg(env);
    var complete_int: c_int = 0;
    _ = nif_get_int(env, argv[2], &complete_int);
    var beam_mat_cache = argv[3];

    const stream: *ZigStreamResource = @ptrCast(@alignCast(raw_res.?));
    const cur_buf = stream.bufSlice();
    if (full_text.len < cur_buf.len or !std.mem.startsWith(u8, full_text, cur_buf)) {
        stream.resetFull();
        beam_mat_cache = nif_make_new_map(env);
        stream.appendChunk(full_text);
    } else if (full_text.len > cur_buf.len) {
        stream.appendChunk(full_text[cur_buf.len..]);
    }
    return computeStreamResult(env, stream, complete_int != 0, beam_mat_cache);
}

export fn zig_stream_get(env: ?*ErlNifEnv, argc: c_int, argv: [*]const ERL_NIF_TERM) ERL_NIF_TERM {
    if (argc != 3) return nif_make_badarg(env);
    var raw_res: ?*anyopaque = null;
    if (nif_get_resource(env, argv[0], STREAM_RESOURCE_TYPE, &raw_res) == 0 or raw_res == null) {
        return nif_make_badarg(env);
    }
    var complete_int: c_int = 0;
    _ = nif_get_int(env, argv[1], &complete_int);
    const beam_mat_cache = argv[2];

    const stream: *ZigStreamResource = @ptrCast(@alignCast(raw_res.?));
    return computeStreamResult(env, stream, complete_int != 0, beam_mat_cache);
}




