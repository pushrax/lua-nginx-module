# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);
#repeat_each(1);

plan tests => repeat_each() * (blocks() * 3);

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: content_by_lua_block (simplest)
--- config
    location = /t {
        content_by_lua_block {
            ngx.say("hello, world")
        }
    }
--- request
GET /t
--- response_body
hello, world
--- no_error_log
[error]



=== TEST 2: content_by_lua_block (nested curly braces)
--- config
    location = /t {
        content_by_lua_block {
            local a = {
                dogs = {32, 78, 96},
                cat = "kitty",
            }
            ngx.say("a.dogs[1] = ", a.dogs[1])
            ngx.say("a.dogs[2] = ", a.dogs[2])
            ngx.say("a.dogs[3] = ", a.dogs[3])
            ngx.say("a.cat = ", a.cat)
        }
    }
--- request
GET /t
--- response_body
a.dogs[1] = 32
a.dogs[2] = 78
a.dogs[3] = 96
a.cat = kitty

--- no_error_log
[error]



=== TEST 3: content_by_lua_block (curly braces in strings)
--- config
    location = /t {
        content_by_lua_block {
            ngx.say("}1, 2)")
            ngx.say('{1, 2)')
        }
    }
--- request
GET /t
--- response_body
}1, 2)
{1, 2)

--- no_error_log
[error]



=== TEST 4: content_by_lua_block (curly braces in strings, with escaped terminators)
--- config
    location = /t {
        content_by_lua_block {
            ngx.say("\"}1, 2)")
            ngx.say('\'{1, 2)')
        }
    }
--- request
GET /t
--- response_body
"}1, 2)
'{1, 2)

--- no_error_log
[error]



=== TEST 5: content_by_lua_block (curly braces in long brackets)
--- config
    location = /t {
        content_by_lua_block {
            --[[
                {{{

                        }
            ]]
            --[==[
                }}}

                        {
            ]==]
            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 6: content_by_lua_block ("nested" long brackets)
--- config
    location = /t {
        content_by_lua_block {
            --[[
                ]=]
            '  "
                        }
            ]]
            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 7: content_by_lua_block (curly braces in line comments)
--- config
    location = /t {
        content_by_lua_block {
            --}} {}
            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 8: content_by_lua_block (cosockets)
--- config
    server_tokens off;
    location = /t {
        content_by_lua_block {
            local sock = ngx.socket.tcp()
            local port = ngx.var.port
            local ok, err = sock:connect('127.0.0.1', tonumber(ngx.var.server_port))
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say('connected: ', ok)

            local req = "GET /foo HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n"
            -- req = "OK"

            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send request: ", err)
                return
            end

            ngx.say("request sent: ", bytes)

            while true do
                local line, err, part = sock:receive()
                if line then
                    ngx.say("received: ", line)

                else
                    ngx.say("failed to receive a line: ", err, " [", part, "]")
                    break
                end
            end

            ok, err = sock:close()
            ngx.say("close: ", ok, " ", err)
        }
    }

    location /foo {
        content_by_lua_block { ngx.say("foo") }
        more_clear_headers Date;
    }

--- request
GET /t
--- response_body
connected: 1
request sent: 57
received: HTTP/1.1 200 OK
received: Server: nginx
received: Content-Type: text/plain
received: Content-Length: 4
received: Connection: close
received: 
received: foo
failed to receive a line: closed []
close: 1 nil
--- no_error_log
[error]
