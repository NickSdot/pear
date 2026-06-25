<?php
declare(strict_types=1);

$staticDir = realpath(__DIR__ . '/..');

if ($staticDir === false) {
    http_response_code(500);
    echo "Static directory does not exist.\n";
    return true;
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$path = is_string($path) && $path !== '' ? $path : '/';

if ($path === '/' || $path === '/pear') {
    header('Location: /pear/', true, 302);
    return true;
}

if (!str_starts_with($path, '/pear/')) {
    http_response_code(404);
    echo "Not found.\n";
    return true;
}

$relative = rawurldecode(substr($path, strlen('/pear/')));

if ($relative === '') {
    $relative = 'index.html';
}

if (str_contains($relative, "\0") || preg_match('#(?:^|/)\.\.(?:/|$)#', $relative) === 1) {
    http_response_code(400);
    echo "Bad request.\n";
    return true;
}

$file = $staticDir . '/' . $relative;

if (is_dir($file)) {
    $file = rtrim($file, '/') . '/index.html';
}

$realFile = realpath($file);

if ($realFile === false || !str_starts_with($realFile, $staticDir . DIRECTORY_SEPARATOR) || !is_file($realFile)) {
    http_response_code(404);
    echo "Not found.\n";
    return true;
}

$types = [
    'css' => 'text/css; charset=UTF-8',
    'html' => 'text/html; charset=UTF-8',
    'ico' => 'image/x-icon',
    'js' => 'text/javascript; charset=UTF-8',
    'json' => 'application/json; charset=UTF-8',
    'png' => 'image/png',
    'svg' => 'image/svg+xml',
    'txt' => 'text/plain; charset=UTF-8',
    'xml' => 'application/xml; charset=UTF-8',
    'xsd' => 'application/xml; charset=UTF-8',
];

$extension = strtolower(pathinfo($realFile, PATHINFO_EXTENSION));

header('Content-Type: ' . ($types[$extension] ?? 'application/octet-stream'));
header('Content-Length: ' . filesize($realFile));
readfile($realFile);

return true;
