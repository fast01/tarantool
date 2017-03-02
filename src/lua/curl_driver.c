/*
 * Copyright (C) 2016-2017 Tarantool AUTHORS: please see AUTHORS file.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include "curl_driver.h"
#include "say.h"
#include "lua/utils.h"
/*
   <async_request> This function does async HTTP request

    Parameters:

        method  - HTTP method, like GET, POST, PUT and so on
        url     - HTTP url, like https://tarantool.org/doc
        options - this is a table of options.

            ca_path - a path to ssl certificate dir;

            ca_file - a path to ssl certificate file;

            headers - a table of HTTP headers;

            max_conns - max amount of cached alive connections;

            keepalive_idle & keepalive_interval - non-universal keepalive knobs (Linux, AIX, HP-UX, more);

            low_speed_time & low_speed_limit - If the download receives less than "low speed limit" bytes/second
                                               during "low speed time" seconds, the operations is aborted.
                                               You could i.e if you have a pretty high speed connection, abort if
                                               it is less than 2000 bytes/sec during 20 seconds;

            read_timeout - Time-out the read operation after this amount of seconds;

            connect_timeout  - Time-out connect operations after this amount of seconds, if connects are;
                               OK within this time, then fine... This only aborts the connect phase;

            dns_cache_timeout - DNS cache timeout;

            curl_verbose - make libcurl verbose!;

        Returns:
              bool, msg or error()
*/
static
int
async_request(lua_State *L)
{
    const char *reason = "unknown error";
    lib_ctx_t *ctx = ctx_get(L);
    if (ctx == NULL)
        return luaL_error(L, "can't get lib ctx");
    ctx->done = false;
    if (ctx->done)
        return luaL_error(L, "curl stopped");

    request_t *r = new_request(ctx->curl_ctx);
    if (r == NULL)
        return luaL_error(L, "can't get request obj from pool");

    request_start_args_t req_args;
    request_start_args_init(&req_args);

    const char *method = luaL_checkstring(L, 2);
    const char *url    = luaL_checkstring(L, 3);
    /** Set Options {{{
     */
    if (lua_istable(L, 4)) {

        const int top = lua_gettop(L);

        /* callback's context */
        lua_pushstring(L, "body");
        lua_gettable(L, 4);

        const char* tmp = lua_tolstring(L, -1, &r->read);
        if (tmp && r->read > 0) {
            r->body = (char*) malloc(sizeof(char) * r->read);
            if (!r->body) {
                reason = "can't allocate memory for passed body";
                goto error_exit;
            }
            memcpy(r->body, tmp, r->read);
        }
        lua_pop(L, 1);

        /** Http headers */
        lua_pushstring(L, "headers");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1)) {
            lua_pushnil(L);
            char header[4096];
            while (lua_next(L, -2) != 0) {
                snprintf(header, sizeof(header) - 1,
                        "%s: %s", lua_tostring(L, -2), lua_tostring(L, -1));
                if (!request_add_header(r, header)) {
                    reason = "can't allocate memory (request_add_header)";
                    goto error_exit;
                }
                lua_pop(L, 1);
            } // while
        }
        lua_pop(L, 1);

        /* SSL/TLS cert  {{{ */
        lua_pushstring(L, "ca_path");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            curl_easy_setopt(r->easy, CURLOPT_CAPATH,
                             lua_tostring(L, top + 1));
        lua_pop(L, 1);

        lua_pushstring(L, "ca_file");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            curl_easy_setopt(r->easy, CURLOPT_CAINFO,
                             lua_tostring(L, top + 1));
        lua_pop(L, 1);
        /* }}} */

        lua_pushstring(L, "max_conns");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.max_conns = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "keepalive_idle");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.keepalive_idle = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "keepalive_interval");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.keepalive_interval = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "low_speed_limit");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.low_speed_limit = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "low_speed_time");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.low_speed_time = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "read_timeout");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.read_timeout = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "connect_timeout");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.connect_timeout = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        lua_pushstring(L, "dns_cache_timeout");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1))
            req_args.dns_cache_timeout = (long) lua_tointeger(L, top + 1);
        lua_pop(L, 1);

        /* Debug- / Internal- options */
        lua_pushstring(L, "curl_verbose");
        lua_gettable(L, 4);
        if (!lua_isnil(L, top + 1) && lua_isboolean(L, top + 1))
            req_args.curl_verbose = true;
        lua_pop(L, 1);
    } else {
        reason = "4-arg have to be a table";
        goto error_exit;
    }
    /* }}} */

    curl_easy_setopt(r->easy, CURLOPT_PRIVATE, (void *) r);

    curl_easy_setopt(r->easy, CURLOPT_URL, url);
    curl_easy_setopt(r->easy, CURLOPT_FOLLOWLOCATION, 1);

    curl_easy_setopt(r->easy, CURLOPT_SSL_VERIFYPEER, 1);

    /* Method {{{ */

    if (strncmp(method, "GET", sizeof("GET") - 1) == 0) {
        curl_easy_setopt(r->easy, CURLOPT_HTTPGET, 1L);
    }
    else if (strncmp(method, "HEAD", sizeof("HEAD") - 1) == 0) {
        curl_easy_setopt(r->easy, CURLOPT_NOBODY, 1L);
    }
    else if (strncmp(method, "POST", sizeof("POST") - 1) == 0) {
        if (!request_set_post(r)) {
            reason = "can't allocate memory (request_set_post)";
            goto error_exit;
        }
    }
    else if (strncmp(method, "PUT", sizeof("PUT") - 1) == 0) {
        if (!request_set_put(r)) {
            reason = "can't allocate memory (request_set_put)";
            goto error_exit;
        }
    }
    else if (strncmp(method, "OPTIONS", sizeof("OPTIONS") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "OPTIONS");  
    }
    else if (strncmp(method, "DELETE", sizeof("DELETE") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "DELETE");  
    }
    else if (strncmp(method, "TRACE", sizeof("TRACE") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "TRACE");  
    }
    else if (strncmp(method, "CONNECT", sizeof("CONNECT") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "CONNECT");  
    }
    else {
        reason = "method does not supported";
        goto error_exit;
    }
    /* }}} */

    /* Note that the add_handle() will set a
     * time-out to trigger very soon so that
     * the necessary socket_action() call will be
     * called by this app */
    CURLMcode rc = request_start(r, &req_args);
    if (rc != CURLM_OK)
        goto error_exit;
    ipc_cond_wait_timeout(r->cond, TIMEOUT_INFINITY);
    int ret = curl_make_result(L, CURL_LAST, rc, r);
    free_request(ctx->curl_ctx, r);
    return ret;

error_exit:
    free_request(ctx->curl_ctx, r);
    return luaL_error(L, reason);
}

static
int
get_stat(lua_State *L)
{
    lib_ctx_t *ctx = ctx_get(L);
    if (ctx == NULL)
        return luaL_error(L, "can't get lib ctx");

    curl_ctx_t *l = ctx->curl_ctx;
    if (l == NULL)
        return luaL_error(L, "it doesn't initialized");

    lua_newtable(L);

    add_field_u64(L, "active_requests", (uint64_t) l->stat.active_requests);
    add_field_u64(L, "sockets_added", (uint64_t) l->stat.sockets_added);
    add_field_u64(L, "sockets_deleted", (uint64_t) l->stat.sockets_deleted);
    add_field_u64(L, "total_requests", l->stat.total_requests);
    add_field_u64(L, "http_200_responses",  l->stat.http_200_responses);
    add_field_u64(L, "http_other_responses", l->stat.http_other_responses);
    add_field_u64(L, "failed_requests", (uint64_t) l->stat.failed_requests);

    return 1;
}


static
int
pool_stat(lua_State *L)
{
    lib_ctx_t *ctx = ctx_get(L);
    if (ctx == NULL)
        return luaL_error(L, "can't get lib ctx");

    curl_ctx_t *l = ctx->curl_ctx;
    if (l == NULL)
        return luaL_error(L, "it doesn't initialized");

    lua_newtable(L);

    add_field_u64(L, "pool_size", (uint64_t) l->cpool.size);
    add_field_u64(L, "free", (uint64_t) request_pool_get_free_size(&l->cpool));

    return 1;
}


/** Lib functions {{{
 */

/** lib C API {{{
 */

int
curl_version()
{
  char version[sizeof("tarantool.curl: xxx.xxx.xxx") +
               sizeof("curl: xxx.xxx.xxx,") +
               sizeof("libev: xxx.xxx") ];
  say(S_INFO, "%s", "hello");
  snprintf(version, sizeof(version) - 1,
            "tarantool.curl: %i.%i.%i, curl: %i.%i.%i, libev: %i.%i",
            TNT_CURL_VERSION_MAJOR,
            TNT_CURL_VERSION_MINOR,
            TNT_CURL_VERSION_PATCH,

            LIBCURL_VERSION_MAJOR,
            LIBCURL_VERSION_MINOR,
            LIBCURL_VERSION_PATCH,

            EV_VERSION_MAJOR,
            EV_VERSION_MINOR );

  return version;
}


lib_ctx_t*
curl_new(bool pipeline, long max_conn, long pool_size, long buffer_size)
{
    lib_ctx_t *ctx = (lib_ctx_t *) malloc (sizeof(lib_ctx_t));

    if (ctx == NULL) {
        say_error("In:%s:%d: Can't allocate memory for curl context", __FILE__, __LINE__);
        return ctx;
    }

    ctx->curl_ctx = NULL;
    ctx->done    = false;

    curl_args_t args = { .pipeline = pipeline,
                         .max_conns = max_conn,
                         .pool_size = pool_size,
                         .buffer_size = buffer_size
                        };

    ctx->curl_ctx = curl_ctx_new(&args);
    if (ctx->curl_ctx == NULL) {
        say_error("In %s:%d: curl_new failed", __FILE__, __LINE__);
        return NULL;
    }
    return ctx;
}

void
curl_free(lib_ctx_t *ctx)
{
    if (ctx == NULL)
      return;

    ctx->done = true;

    curl_destroy(ctx->curl_ctx);
}


response_t
request(lib_ctx_t *ctx, const char* method, const char* url, const options_t* options)
{
    const char *reason = "unknown error";
    if (ctx == NULL) {
        say_error("can't get lib ctx");
        return NULL;
    }
    ctx->done = false;
    if (ctx->done) {
        say_error("curl stopped");
        return NULL;
    }

    request_t *r = new_request(ctx->curl_ctx);
    if (r == NULL) {
        say_error("can't get request obj from pool");
        return NULL;
    }
    request_start_args_t req_args;
    request_start_args_init(&req_args);

    /** Set Options {{{
     */

    if (options->body) {
        r->body = (char*) malloc(sizeof(char) * r->read);
        if (!r->body) {
            reason = "can't allocate memory for passed body";
            goto error_exit;
        }
        memcpy(r->body, tmp, r->read);
    }

    /** Http headers */
//    lua_pushstring(L, "headers");
//    lua_gettable(L, 4);
//    if (!lua_isnil(L, top + 1)) {
//        lua_pushnil(L);
//        char header[4096];
//        while (lua_next(L, -2) != 0) {
//            snprintf(header, sizeof(header) - 1,
//                    "%s: %s", lua_tostring(L, -2), lua_tostring(L, -1));
//            if (!request_add_header(r, header)) {
//                reason = "can't allocate memory (request_add_header)";
//                goto error_exit;
//            }
//            lua_pop(L, 1);
//        } // while
//    }
 
    /* SSL/TLS cert  {{{ */
    if (options->ca_path)
        curl_easy_setopt(r->easy, CURLOPT_CAPATH, options->ca_path);
 
    if (options->ca_file)
        curl_easy_setopt(r->easy, CURLOPT_CAINFO, options->ca_file);
    /* }}} */
 
    req_args.max_conns = options->max_conns;
    req_args.keepalive_idle = options->keepalive_idle;
    req_args.keepalive_interval = ;
    req_args.low_speed_limit = options->low_speed_limit;
    req_args.low_speed_time = options->low_speed_time;
    req_args.read_timeout = options->read_timeout;
    req_args.connect_timeout = options->connect_timeout;
    req_args.dns_cache_timeout = options->dns_cache_timeout;
 
    /* Debug- / Internal- options */
    req_args.curl_verbose = options->verbose;

    curl_easy_setopt(r->easy, CURLOPT_PRIVATE, (void *) r);

    curl_easy_setopt(r->easy, CURLOPT_URL, url);
    curl_easy_setopt(r->easy, CURLOPT_FOLLOWLOCATION, 1);

    curl_easy_setopt(r->easy, CURLOPT_SSL_VERIFYPEER, 1);

    /* Method {{{ */

    if (strncmp(method, "GET", sizeof("GET") - 1) == 0) {
        curl_easy_setopt(r->easy, CURLOPT_HTTPGET, 1L);
    }
    else if (strncmp(method, "HEAD", sizeof("HEAD") - 1) == 0) {
        curl_easy_setopt(r->easy, CURLOPT_NOBODY, 1L);
    }
    else if (strncmp(method, "POST", sizeof("POST") - 1) == 0) {
        if (!request_set_post(r)) {
            reason = "can't allocate memory (request_set_post)";
            goto error_exit;
        }
    }
    else if (strncmp(method, "PUT", sizeof("PUT") - 1) == 0) {
        if (!request_set_put(r)) {
            reason = "can't allocate memory (request_set_put)";
            goto error_exit;
        }
    }
    else if (strncmp(method, "OPTIONS", sizeof("OPTIONS") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "OPTIONS");  
    }
    else if (strncmp(method, "DELETE", sizeof("DELETE") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "DELETE");  
    }
    else if (strncmp(method, "TRACE", sizeof("TRACE") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "TRACE");  
    }
    else if (strncmp(method, "CONNECT", sizeof("CONNECT") - 1) == 0) {
         curl_easy_setopt(r->easy, CURLOPT_CUSTOMREQUEST, "CONNECT");  
    }
    else {
        reason = "method does not supported";
        goto error_exit;
    }
    /* }}} */

    /* Note that the add_handle() will set a
     * time-out to trigger very soon so that
     * the necessary socket_action() call will be
     * called by this app */
    CURLMcode rc = request_start(r, &req_args);
    if (rc != CURLM_OK)
        goto error_exit;
    ipc_cond_wait_timeout(r->cond, TIMEOUT_INFINITY);
    response_t* ret = curl_result(CURL_LAST, rc, r);
    free_request(ctx->curl_ctx, r);
    return ret;

error_exit:
    free_request(ctx->curl_ctx, r);
    return luaL_error(L, reason);

}
/* }}}
 * */


/** lib Lua API {{{
 */
static
int
version(lua_State *L)
{
  char version[sizeof("tarantool.curl: xxx.xxx.xxx") +
               sizeof("curl: xxx.xxx.xxx,") +
               sizeof("libev: xxx.xxx") ];
    say(S_INFO, "%s", "hello");
  snprintf(version, sizeof(version) - 1,
            "tarantool.curl: %i.%i.%i, curl: %i.%i.%i, libev: %i.%i",
            TNT_CURL_VERSION_MAJOR,
            TNT_CURL_VERSION_MINOR,
            TNT_CURL_VERSION_PATCH,

            LIBCURL_VERSION_MAJOR,
            LIBCURL_VERSION_MINOR,
            LIBCURL_VERSION_PATCH,

            EV_VERSION_MAJOR,
            EV_VERSION_MINOR );

  return make_str_result(L, true, version);
}



static
int
new(lua_State *L)
{

    lib_ctx_t *ctx = (lib_ctx_t *)
            lua_newuserdata(L, sizeof(lib_ctx_t));
    if (ctx == NULL)
        return luaL_error(L, "lua_newuserdata failed: lib_ctx_t");

    ctx->curl_ctx = NULL;
    ctx->done    = false;

    curl_args_t args = { .pipeline = false,
                         .max_conns = 5,
                         .pool_size = 10000,
                         .buffer_size = 2048
                        };

    /* pipeline: 1 - on, 0 - off */
    args.pipeline  = (bool) luaL_checkint(L, 1);
    args.max_conns = luaL_checklong(L, 2);
    args.pool_size = (size_t) luaL_checklong(L, 3);
    args.buffer_size = (size_t) luaL_checklong(L, 4);
    ctx->curl_ctx = curl_ctx_new(&args);
    if (ctx->curl_ctx == NULL)
        return luaL_error(L, "curl_new failed");


    luaL_getmetatable(L, DRIVER_LUA_UDATA_NAME);
    lua_setmetatable(L, -2);

    return 1;
}



static
int
cleanup(lua_State *L)
{
    curl_free(ctx_get(L));

    /* remove all methods operating on ctx */
    lua_newtable(L);
    lua_setmetatable(L, -2);

    return make_int_result(L, true, 0);
}


/*
 * Lists of exporting: object and/or functions to the Lua
 */

static const struct luaL_Reg R[] = {
    {"version", version},
    {"new",     new},
    {NULL,      NULL}
};

static const struct luaL_Reg M[] = {
    {"async_request", async_request},
    {"stat",          get_stat},
    {"pool_stat",     pool_stat},
    {"free",          cleanup /* free already exists */},
    {NULL,            NULL}
};

/*
 * Lib initializer
 */
LUA_API
int
luaopen_curl_driver(lua_State *L)
{
	luaL_register_type(L, DRIVER_LUA_UDATA_NAME, M);
	luaL_register(L, "curl.driver", R);
	return 1;
}