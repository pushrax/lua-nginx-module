use Test::Nginx::Socket::Lua;

#master_on();
#workers(1);
#worker_connections(1014);
#log_level('warn');
#master_process_enabled(1);

repeat_each(2);

plan tests => repeat_each() * blocks() * 2;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

#no_diff();
no_long_string();
#no_shuffle();

run_tests();

__DATA__

=== TEST 1: not internal request
--- config
    location /test {
        rewrite ^/test$ /lua last;
    }
    location /lua {
        content_by_lua '
            if ngx.req.is_internal() then
                ngx.say("internal")
            else
                ngx.say("not internal")
            end
        ';
    }
--- request
GET /lua
--- response_body
not internal



=== TEST 2: internal request
--- config
    location /test {
        rewrite ^/test$ /lua last;
    }
    location /lua {
        content_by_lua '
            if ngx.req.is_internal() then
                ngx.say("internal")
            else
                ngx.say("not internal")
            end
        ';
    }
--- request
GET /test
--- response_body
internal



=== TEST 3: upstream_name with valid explicit upstream
--- http_config
    upstream some_upstream {
        server 127.0.0.1:$TEST_NGINX_SERVER_PORT;
    }
--- config
    log_by_lua_block {
        ngx.log(ngx.INFO, "upstream = " .. tostring(ngx.req.upstream_name()))
    }
    location /test {
        proxy_pass http://some_upstream/back;
    }
    location /back {
        echo ok;
    }
--- request
GET /test
--- log_level: info
--- error_log eval
qr/upstream = some_upstream/



=== TEST 4: upstream_name with valid implicit upstream
--- config
    log_by_lua_block {
        ngx.log(ngx.INFO, "upstream = " .. tostring(ngx.req.upstream_name()))
    }
    location /test {
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/back;
    }
    location /back {
        echo ok;
    }
--- request
GET /test
--- log_level: info
--- error_log eval
qr/upstream = 127.0.0.1:\d+/



=== TEST 5: upstream_name with no proxy_pass
--- config
    log_by_lua_block {
        ngx.log(ngx.INFO, "upstream = " .. tostring(ngx.req.upstream_name()))
    }
    location /test {
        echo ok;
    }
--- request
GET /test
--- log_level: info
--- error_log eval
qr/upstream = nil/



=== TEST 6: upstream_name in content_by_lua
--- config
    location /test {
        content_by_lua_block {
            ngx.say(ngx.req.upstream_name())
        }
    }
--- request
GET /test
--- response_body
nil

