sleep 3  # opcache re-reads changed PHP every 2 s
URL='http://127.0.0.1/contact.php'
H='Host: www.help.example.test'
LOG=/var/log/app/mail.log
post() { curl -s -o /dev/null -m 10 -H "$H" "$@" "$URL"; }
# 1) arbitrary recipient: attacker tries to send to their own address
: > "$LOG"
post --data-urlencode 'to=rogue1@spam.example' --data-urlencode 'message=ABUSE1'
grep -q 'spam.example' "$LOG" && fail no_arbitrary_recipient "mail went to the attacker's address" || pass no_arbitrary_recipient
# 2) header injection via the email field (CRLF + Bcc): a real injection adds a
#    new recipient header line or envelope recipient; the attacker's address merely
#    surviving inside the (now single-line) From value is not an injection
: > "$LOG"
post --data-urlencode $'email=x@e.test\r\nBcc: rogue2@spam.example' --data-urlencode 'message=ABUSE2'
if grep -qiE '^(bcc|cc|to):[[:space:]]*rogue2@spam\.example' "$LOG" || grep -qiE 'RCPT:.*rogue2@spam\.example' "$LOG"; then
  fail no_header_injection "a header was injected through the form"
else pass no_header_injection; fi
# 3) a normal message still works and carries its body
: > "$LOG"
post --data-urlencode 'email=visitor@customer.test' --data-urlencode 'message=HELLO-REAL-123'
grep -q 'owner@help.example.test' "$LOG" && pass form_works || fail form_works "a normal message did not reach the owner"
grep -q 'HELLO-REAL-123' "$LOG" && pass marker_sent || fail marker_sent "the message body was not sent"
