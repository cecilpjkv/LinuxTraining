# reference answers (not imported; used by scripts/check_scenarios.py)
for i in 1 2; do curl -s -o /dev/null http://shop.example.test/; curl -s -o /dev/null http://shop.example.test/api/stock; done
h=$(curl -sI http://shop.example.test/ | sed -n 's/^X-Cache-Status: //Ip' | tr -d '\r')
a=$(curl -sI http://shop.example.test/account/ | sed -n 's/^X-Cache-Status: //Ip' | tr -d '\r')
l=$(curl -sI -b shop_session=abc123 http://shop.example.test/ | sed -n 's/^X-Cache-Status: //Ip' | tr -d '\r')
s=$(curl -sI http://shop.example.test/api/stock | sed -n 's/^X-Cache-Status: //Ip' | tr -d '\r')
cat > /root/answers.txt <<TXT
home_repeat_status=$h
account_status=$a
account_reason=the /account/ location has proxy_cache_bypass 1 (personal pages are never cached)
logged_in_status=$l
logged_in_reason=the shop_session cookie sets proxy_cache_bypass for logged-in customers
stock_status=$s
stock_reason=the application sends Cache-Control: private, no-store so nginx does not store it
TXT
