# cython: language_level=3

from libc.stdint cimport uint64_t, uint32_t, int32_t, int64_t, uint8_t


cdef extern from "lo/lo.h" nogil:

    cdef struct _lo_split64_lo_split64_part_s:
        uint32_t a
        uint32_t b

    ctypedef union lo_split64:
        uint64_t all
        _lo_split64_lo_split64_part_s part

    uint64_t lo_swap64(uint64_t x)

    ctypedef struct lo_timetag:
        uint32_t sec
        uint32_t frac

    ctypedef enum lo_element_type:
        LO_ELEMENT_MESSAGE
        LO_ELEMENT_BUNDLE

    ctypedef enum lo_type:
        LO_INT32
        LO_FLOAT
        LO_STRING
        LO_BLOB
        LO_INT64
        LO_TIMETAG
        LO_DOUBLE
        LO_SYMBOL
        LO_CHAR
        LO_MIDI
        LO_TRUE
        LO_FALSE
        LO_NIL
        LO_INFINITUM

    cdef struct _lo_arg_lo_arg_blob_s:
        int32_t size
        char data

    ctypedef union lo_arg:
        int32_t i
        int32_t i32
        int64_t h
        int64_t i64
        float f
        float f32
        double d
        double f64
        char s
        char S
        unsigned char c
        uint8_t m[4]
        lo_timetag t
        _lo_arg_lo_arg_blob_s blob

    ctypedef void* lo_address

    ctypedef void* lo_blob

    ctypedef void* lo_message

    ctypedef void* lo_bundle

    ctypedef void* lo_method

    ctypedef void* lo_server

    ctypedef void* lo_server_thread

    ctypedef void (*lo_err_handler)(int num, char* msg, char* where)

    ctypedef int (*lo_method_handler)(char* path, char* types, lo_arg** argv, int argc, lo_message msg, void* user_data)

    ctypedef int (*lo_bundle_start_handler)(lo_timetag time, void* user_data)

    ctypedef int (*lo_bundle_end_handler)(void* user_data)

    ctypedef int (*lo_server_thread_init_callback)(lo_server_thread s, void* user_data)

    ctypedef void (*lo_server_thread_cleanup_callback)(lo_server_thread s, void* user_data)

    ctypedef long double lo_hires

    int lo_send_message(lo_address targ, char* path, lo_message msg)

    int lo_send_message_from(lo_address targ, lo_server serv, char* path, lo_message msg)

    int lo_send_bundle(lo_address targ, lo_bundle b)

    int lo_send_bundle_from(lo_address targ, lo_server serv, lo_bundle b)

    lo_message lo_message_new()

    void lo_message_incref(lo_message m)

    lo_message lo_message_clone(lo_message m)

    void lo_message_free(lo_message m)

    int lo_message_add(lo_message m, char* types)

    int lo_message_add_internal(lo_message m, char* file, int line, char* types)

    # int lo_message_add_varargs(lo_message m, char* types, va_list ap)

    # int lo_message_add_varargs_internal(lo_message m, char* types, va_list ap, char* file, int line)

    int lo_message_add_int32(lo_message m, int32_t a)

    int lo_message_add_float(lo_message m, float a)

    int lo_message_add_string(lo_message m, char* a)

    int lo_message_add_blob(lo_message m, lo_blob a)

    int lo_message_add_int64(lo_message m, int64_t a)

    int lo_message_add_timetag(lo_message m, lo_timetag a)

    int lo_message_add_double(lo_message m, double a)

    int lo_message_add_symbol(lo_message m, char* a)

    int lo_message_add_char(lo_message m, char a)

    int lo_message_add_midi(lo_message m, uint8_t a[4])

    int lo_message_add_true(lo_message m)

    int lo_message_add_false(lo_message m)

    int lo_message_add_nil(lo_message m)

    int lo_message_add_infinitum(lo_message m)

    lo_address lo_message_get_source(lo_message m)

    lo_timetag lo_message_get_timestamp(lo_message m)

    char* lo_message_get_types(lo_message m)

    int lo_message_get_argc(lo_message m)

    lo_arg** lo_message_get_argv(lo_message m)

    size_t lo_message_length(lo_message m, char* path)

    void* lo_message_serialise(lo_message m, char* path, void* to, size_t* size)

    lo_message lo_message_deserialise(void* data, size_t size, int* result)

    int lo_server_dispatch_data(lo_server s, void* data, size_t size)

    char* lo_address_get_hostname(lo_address a)

    char* lo_address_get_port(lo_address a)

    int lo_address_get_protocol(lo_address a)

    char* lo_address_get_url(lo_address a)

    void lo_address_set_ttl(lo_address t, int ttl)

    int lo_address_get_ttl(lo_address t)

    int lo_address_set_iface(lo_address t, char* iface, char* ip)

    char* lo_address_get_iface(lo_address t)

    int lo_address_set_tcp_nodelay(lo_address t, int enable)

    int lo_address_set_stream_slip(lo_address t, int enable)

    lo_bundle lo_bundle_new(lo_timetag tt)

    void lo_bundle_incref(lo_bundle b)

    int lo_bundle_add_message(lo_bundle b, char* path, lo_message m)

    int lo_bundle_add_bundle(lo_bundle b, lo_bundle n)

    size_t lo_bundle_length(lo_bundle b)

    unsigned int lo_bundle_count(lo_bundle b)

    lo_element_type lo_bundle_get_type(lo_bundle b, int index)

    lo_bundle lo_bundle_get_bundle(lo_bundle b, int index)

    lo_message lo_bundle_get_message(lo_bundle b, int index, char** path)

    lo_timetag lo_bundle_get_timestamp(lo_bundle b)

    void* lo_bundle_serialise(lo_bundle b, void* to, size_t* size)

    void lo_bundle_free(lo_bundle b)

    void lo_bundle_free_recursive(lo_bundle b)

    void lo_bundle_free_messages(lo_bundle b)

    int lo_is_numerical_type(lo_type a)

    int lo_is_string_type(lo_type a)

    int lo_coerce(lo_type type_to, lo_arg* to, lo_type type_from, lo_arg* from_)

    lo_hires lo_hires_val(lo_type t, lo_arg* p)

    lo_server lo_server_new(char* port, lo_err_handler err_h)

    lo_server lo_server_new_with_proto(char* port, int proto, lo_err_handler err_h)

    lo_server lo_server_new_multicast(char* group, char* port, lo_err_handler err_h)

    # Added in 0.30, but current homebrew
    lo_server lo_server_new_multicast_iface(char* group, char* port, char* iface, char* ip, lo_err_handler err_h)

    lo_server lo_server_new_from_url(char* url, lo_err_handler err_h)

    int lo_server_enable_coercion(lo_server server, int enable)

    void lo_server_free(lo_server s)

    int lo_server_wait(lo_server s, int timeout)

    int lo_servers_wait(lo_server* s, int* status, int num_servers, int timeout)

    int lo_server_recv_noblock(lo_server s, int timeout)

    int lo_servers_recv_noblock(lo_server* s, int* recvd, int num_servers, int timeout)

    int lo_server_recv(lo_server s)

    lo_method lo_server_add_method(lo_server s, char* path, char* typespec, lo_method_handler h, void* user_data)

    void lo_server_del_method(lo_server s, char* path, char* typespec)

    int lo_server_del_lo_method(lo_server s, lo_method m)

    int lo_server_add_bundle_handlers(lo_server s, lo_bundle_start_handler sh, lo_bundle_end_handler eh, void* user_data)

    int lo_server_get_socket_fd(lo_server s)

    int lo_server_get_port(lo_server s)

    int lo_server_get_protocol(lo_server s)

    char* lo_server_get_url(lo_server s)

    int lo_server_enable_queue(lo_server s, int queue_enabled, int dispatch_remaining)

    int lo_server_events_pending(lo_server s)

    void lo_server_set_error_context(lo_server s, void *user_data)

    double lo_server_next_event_delay(lo_server s)

    int lo_server_max_msg_size(lo_server s, int req_size)

    char* lo_url_get_protocol(char* url)

    int lo_url_get_protocol_id(char* url)

    char* lo_url_get_hostname(char* url)

    char* lo_url_get_port(char* url)

    char* lo_url_get_path(char* url)

    int lo_strsize(char* s)

    uint32_t lo_blobsize(lo_blob b)

    int lo_pattern_match(char* string, char* pattern)

    double lo_timetag_diff(lo_timetag a, lo_timetag b)

    void lo_timetag_now(lo_timetag* t)

    size_t lo_arg_size(lo_type t, void* data)

    char* lo_get_path(void* data, ssize_t size)

    void lo_arg_host_endian(lo_type t, void* data)

    void lo_arg_network_endian(lo_type t, void* data)

    void lo_bundle_pp(lo_bundle b)

    void lo_message_pp(lo_message m)

    void lo_arg_pp(lo_type t, void* data)

    void lo_server_pp(lo_server s)

    void lo_method_pp(lo_method m)

    void lo_method_pp_prefix(lo_method m, char* p)

    lo_server_thread lo_server_thread_new(char* port, lo_err_handler err_h)

    lo_server_thread lo_server_thread_new_multicast(char* group, char* port, lo_err_handler err_h)

    IF LO_VERSION >= "0.30":
        lo_server_thread lo_server_thread_new_multicast_iface(char* group, char* port, char* iface, char* ip, lo_err_handler err_h)

    lo_server_thread lo_server_thread_new_with_proto(char* port, int proto, lo_err_handler err_h)

    lo_server_thread lo_server_thread_new_from_url(char* url, lo_err_handler err_h)

    void lo_server_thread_free(lo_server_thread st)

    lo_method lo_server_thread_add_method(lo_server_thread st, char* path, char* typespec, lo_method_handler h, void* user_data)

    void lo_server_thread_del_method(lo_server_thread st, char* path, char* typespec)

    int lo_server_thread_del_lo_method(lo_server_thread st, lo_method m)

    void lo_server_thread_set_callbacks(lo_server_thread st, lo_server_thread_init_callback init, lo_server_thread_cleanup_callback cleanup, void* user_data)

    int lo_server_thread_start(lo_server_thread st)

    int lo_server_thread_stop(lo_server_thread st)

    int lo_server_thread_get_port(lo_server_thread st)

    char* lo_server_thread_get_url(lo_server_thread st)

    lo_server lo_server_thread_get_server(lo_server_thread st)

    int lo_server_thread_events_pending(lo_server_thread st)

    void lo_server_thread_set_error_context(lo_server_thread st, void* user_data)

    void lo_server_thread_pp(lo_server_thread st)

    lo_address lo_address_new(char* host, char* port)

    lo_address lo_address_new_with_proto(int proto, char* host, char* port)

    lo_address lo_address_new_from_url(char* url)

    void lo_address_free(lo_address t)

    void lo_address_set_ttl(lo_address t, int ttl)

    int lo_address_get_ttl(lo_address t)

    int lo_send_from(lo_address targ, lo_server from_, lo_timetag ts, char* path, char* t, ...)

    int lo_send_timestamped(lo_address targ, lo_timetag ts, char* path, char* t, ...)

    int lo_address_errno(lo_address a)

    char* lo_address_errstr(lo_address a)

    lo_blob lo_blob_new(int32_t size, void* data)

    void lo_blob_free(lo_blob b)

    uint32_t lo_blob_datasize(lo_blob b)

    void* lo_blob_dataptr(lo_blob b)

    void * lo_error_get_context()

    void lo_version(char* verstr, int verstr_size, int* major, int* minor, char* extra, int extra_size, int* lt_major, int* lt_minor, int* lt_bug)


ctypedef struct lo_address_header:
    char * host
    int socket


# This is only needed so the module gets an init
cdef class Nothing:
    pass