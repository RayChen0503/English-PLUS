@echo off
setlocal
pushd "%~dp0.."
node --loader ./firebase-tests/cloudflare-workers-loader.mjs --test --test-concurrency=1 ./firebase-tests/test/*.test.js
set "test_exit=%errorlevel%"
popd
exit /b %test_exit%
