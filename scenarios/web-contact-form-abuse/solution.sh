# reference fix: hardcode the recipient, strip CR/LF from anything the user supplies
cat > /srv/www/help/contact.php <<'PHP'
<?php
$strip = function ($s) { return str_replace(array("\r", "\n"), '', (string)$s); };
$from    = isset($_POST['email']) ? $strip($_POST['email']) : 'anon@example';
$message = isset($_POST['message']) ? $_POST['message'] : '';
$headers = "From: $from\r\nReply-To: $from\r\n";
mail('owner@help.example.test', 'Website contact', $message, $headers);
echo "SENT-OK";
PHP
chown apache:apache /srv/www/help/contact.php
