#include <erl_nif.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations of Zig NIF functions
extern int zig_nif_load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info);
extern ERL_NIF_TERM zig_preprocess(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_demux(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_strip_comments(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_auto_close(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_tokenize(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_parse_statements(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_parse_source(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_parse_pending(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_parse_symbols(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_parse_merge_statements(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_register_schema(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_parse_and_materialize(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_stream_new(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_stream_reset(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_stream_push(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_stream_set(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
extern ERL_NIF_TERM zig_stream_get(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

// C ABI helpers called from Zig
int nif_inspect_binary(ErlNifEnv* env, ERL_NIF_TERM term, const unsigned char** data_out, size_t* size_out) {
    ErlNifBinary bin;
    if (!enif_inspect_binary(env, term, &bin)) return 0;
    *data_out = bin.data;
    *size_out = bin.size;
    return 1;
}

int nif_get_int(ErlNifEnv* env, ERL_NIF_TERM term, int* val_out) {
    return enif_get_int(env, term, val_out);
}

int nif_get_uint(ErlNifEnv* env, ERL_NIF_TERM term, unsigned int* val_out) {
    return enif_get_uint(env, term, val_out);
}

ERL_NIF_TERM nif_make_binary_slice(ErlNifEnv* env, const unsigned char* src, size_t len) {
    ERL_NIF_TERM term;
    unsigned char* dst = enif_make_new_binary(env, len, &term);
    if (len > 0 && src != NULL) {
        memcpy(dst, src, len);
    }
    return term;
}

ERL_NIF_TERM nif_make_sub_binary(ErlNifEnv* env, ERL_NIF_TERM bin_term, size_t pos, size_t size) {
    return enif_make_sub_binary(env, bin_term, pos, size);
}

ERL_NIF_TERM nif_make_atom_len(ErlNifEnv* env, const char* name, size_t len) {
    return enif_make_atom_len(env, name, len);
}

ERL_NIF_TERM nif_make_int64(ErlNifEnv* env, int64_t val) {
    return enif_make_int64(env, (ErlNifSInt64)val);
}

ERL_NIF_TERM nif_make_double(ErlNifEnv* env, double val) {
    return enif_make_double(env, val);
}

ERL_NIF_TERM nif_make_tuple2(ErlNifEnv* env, ERL_NIF_TERM e1, ERL_NIF_TERM e2) {
    return enif_make_tuple2(env, e1, e2);
}

ERL_NIF_TERM nif_make_tuple3(ErlNifEnv* env, ERL_NIF_TERM e1, ERL_NIF_TERM e2, ERL_NIF_TERM e3) {
    return enif_make_tuple3(env, e1, e2, e3);
}

ERL_NIF_TERM nif_make_tuple4(ErlNifEnv* env, ERL_NIF_TERM e1, ERL_NIF_TERM e2, ERL_NIF_TERM e3, ERL_NIF_TERM e4) {
    return enif_make_tuple4(env, e1, e2, e3, e4);
}

ERL_NIF_TERM nif_make_tuple5(ErlNifEnv* env, ERL_NIF_TERM e1, ERL_NIF_TERM e2, ERL_NIF_TERM e3, ERL_NIF_TERM e4, ERL_NIF_TERM e5) {
    return enif_make_tuple5(env, e1, e2, e3, e4, e5);
}

ERL_NIF_TERM nif_make_list_from_array(ErlNifEnv* env, const ERL_NIF_TERM* arr, unsigned int cnt) {
    return enif_make_list_from_array(env, arr, cnt);
}

int nif_make_map_from_arrays(ErlNifEnv* env, ERL_NIF_TERM* keys, ERL_NIF_TERM* vals, size_t cnt, ERL_NIF_TERM* map_out) {
    return enif_make_map_from_arrays(env, keys, vals, cnt, map_out);
}

ERL_NIF_TERM nif_make_new_map(ErlNifEnv* env) {
    return enif_make_new_map(env);
}

int nif_get_map_value(ErlNifEnv* env, ERL_NIF_TERM map, ERL_NIF_TERM key, ERL_NIF_TERM* val_out) {
    return enif_get_map_value(env, map, key, val_out);
}

int nif_make_map_put(ErlNifEnv* env, ERL_NIF_TERM map_in, ERL_NIF_TERM key, ERL_NIF_TERM val, ERL_NIF_TERM* map_out) {
    return enif_make_map_put(env, map_in, key, val, map_out);
}

int nif_make_map_remove(ErlNifEnv* env, ERL_NIF_TERM map_in, ERL_NIF_TERM key, ERL_NIF_TERM* map_out) {
    return enif_make_map_remove(env, map_in, key, map_out);
}

ErlNifResourceType* nif_open_resource_type(ErlNifEnv* env, const char* name, void (*dtor)(ErlNifEnv*, void*)) {
    return enif_open_resource_type(env, NULL, name, dtor, ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);
}

void* nif_alloc_resource(ErlNifResourceType* type, size_t size) {
    return enif_alloc_resource(type, size);
}

ERL_NIF_TERM nif_make_resource(ErlNifEnv* env, void* obj) {
    return enif_make_resource(env, obj);
}

void nif_release_resource(void* obj) {
    if (obj != NULL) enif_release_resource(obj);
}

int nif_get_resource(ErlNifEnv* env, ERL_NIF_TERM term, ErlNifResourceType* type, void** objp) {
    return enif_get_resource(env, term, type, objp);
}

ERL_NIF_TERM nif_make_badarg(ErlNifEnv* env) {
    return enif_make_badarg(env);
}

void* nif_alloc(size_t size) {
    return enif_alloc(size);
}

void nif_free(void* ptr) {
    if (ptr != NULL) enif_free(ptr);
}

double nif_parse_double(const unsigned char* ptr, size_t len) {
    char buf[128];
    if (len == 0 || len >= sizeof(buf)) return 0.0;
    memcpy(buf, ptr, len);
    buf[len] = '\0';
    return strtod(buf, NULL);
}

size_t nif_format_double(double val, char* buf, size_t buf_size) {
    if (buf_size == 0) return 0;
    int n = snprintf(buf, buf_size, "%.15g", val);
    if (n < 0) return 0;
    return (size_t)n < buf_size ? (size_t)n : buf_size - 1;
}

static ErlNifFunc nif_funcs[] = {
    {"preprocess", 1, zig_preprocess, 0},
    {"demux", 1, zig_demux, 0},
    {"strip_comments", 1, zig_strip_comments, 0},
    {"auto_close", 1, zig_auto_close, 0},
    {"tokenize", 1, zig_tokenize, 0},
    {"raw_parse_statements", 2, zig_parse_statements, 0},
    {"raw_parse_source", 2, zig_parse_source, 0},
    {"raw_parse_pending", 2, zig_parse_pending, 0},
    {"parse_symbols", 1, zig_parse_symbols, 0},
    {"parse_merge_statements", 2, zig_parse_merge_statements, 0},
    {"register_schema", 2, zig_register_schema, 0},
    {"parse_and_materialize", 4, zig_parse_and_materialize, 0},
    {"stream_new", 3, zig_stream_new, 0},
    {"stream_reset", 1, zig_stream_reset, 0},
    {"stream_push", 4, zig_stream_push, 0},
    {"stream_set", 4, zig_stream_set, 0},
    {"stream_get", 3, zig_stream_get, 0}
};

ERL_NIF_INIT(Elixir.OpenUILang.ZigNIF, nif_funcs, zig_nif_load, NULL, NULL, NULL)
