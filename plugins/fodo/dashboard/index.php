<?php
/**
 * fodo dashboard — overview of every repo registered by the fodo Claude Code plugin.
 * Served by /fodo:web (PHP built-in server on 127.0.0.1, see scripts/web.sh) or by Laravel Valet as fodo.test (/fodo:valet).
 * Styling: style.css (standalone, PipelinePro tokens, system fonts only); no CSS framework.
 * Reads ~/.claude/todo/repos.csv and each repo's docs/todo/{,plan,busy,done,skipped,someday}/20*.md as text.
 * Live Claude Code sessions (~/.claude/sessions/<pid>.json, process checked with signal 0) show as agent badges;
 * the overview reloads itself every minute (meta refresh, no JS network calls).
 * /config picks the header/body font (system fonts only) and the color scheme, stored in ~/.claude/todo/config.json.
 * /agents lists Claude Code sessions from `claude agents --json --all` (the only command the dashboard runs; no shell,
 * 5 s timeout) and, for the selected session, peeks at the tail of its transcript (~/.claude/projects/<dir>/<id>.jsonl).
 * No dependencies; nothing from the registered repos is ever included or executed.
 */
declare(strict_types=1);

$home       = getenv('HOME') ?: (posix_getpwuid(posix_geteuid())['dir'] ?? '/Users/' . get_current_user());
$dataDir    = getenv('TODO_REGISTRY_DIR') ?: $home . '/.claude/todo';
$registry   = $dataDir . '/repos.csv';
$configFile = $dataDir . '/config.json';
$claudeDir  = getenv('CLAUDE_CONFIG_DIR') ?: $home . '/.claude';
$sessionDir = $claudeDir . '/sessions';
$claudeBin  = getenv('FODO_CLAUDE_BIN') ?: (stored_claude_bin($dataDir . '/claude-bin') ?: 'claude'); // Valet's PHP-FPM has no shell PATH
$version    = (string) (json_decode((string) @file_get_contents(dirname(__DIR__) . '/.claude-plugin/plugin.json'), true)['version'] ?? ''); // plugin version
$showAll    = isset($_GET['all']);
$tableView  = ($_GET['view'] ?? '') === 'table'; // repo detail page: tables instead of the kanban board
$repoView   = isset($_GET['repo']) && $_GET['repo'] !== '' ? (int) $_GET['repo'] : null;
$urlPath    = (string) parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$configView = rtrim($urlPath, '/') === '/config';
$agentsView = rtrim($urlPath, '/') === '/agents';
$faqView    = rtrim($urlPath, '/') === '/faq';

/**
 * selectable fonts: key => [label, CSS font stack], grouped for the <select>. All are macOS fonts that every browser can use
 * (hidden system fonts like SF Pro Rounded, New York and SF Mono are Safari-only, so not listed); each stack falls back to a look-alike on Windows (Office/core fonts) and Linux (URW/Noto/DejaVu).
 */
const FONTS = [
    'Sans-serif' => [
        'system'    => ['System UI (SF Pro)', 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'],
        'helvetica' => ['Helvetica Neue', '"Helvetica Neue", Helvetica, Arial, sans-serif'],
        'avenir'    => ['Avenir Next', '"Avenir Next", Avenir, system-ui, sans-serif'],
        'seravek'   => ['Seravek', 'Seravek, "Gill Sans", system-ui, sans-serif'],
        'gill'      => ['Gill Sans', '"Gill Sans", "Gill Sans MT", system-ui, sans-serif'],
        'futura'    => ['Futura', 'Futura, "Century Gothic", "URW Gothic", "Trebuchet MS", system-ui, sans-serif'],
        'optima'    => ['Optima', 'Optima, Candara, system-ui, sans-serif'],
        'verdana'   => ['Verdana', 'Verdana, Geneva, sans-serif'],
        'trebuchet' => ['Trebuchet MS', '"Trebuchet MS", system-ui, sans-serif'],
    ],
    'Serif' => [
        'charter'     => ['Charter', 'Charter, "Bitstream Charter", Georgia, serif'],
        'iowan'       => ['Iowan Old Style', '"Iowan Old Style", "Palatino Linotype", Georgia, serif'],
        'georgia'     => ['Georgia', 'Georgia, serif'],
        'palatino'    => ['Palatino', 'Palatino, "Palatino Linotype", "Book Antiqua", "URW Palladio L", P052, "TeX Gyre Pagella", Georgia, serif'],
        'baskerville' => ['Baskerville', 'Baskerville, "Baskerville Old Face", Georgia, serif'],
        'hoefler'     => ['Hoefler Text', '"Hoefler Text", Georgia, serif'],
        'athelas'     => ['Athelas', 'Athelas, Georgia, serif'],
        'didot'       => ['Didot', 'Didot, "Bodoni 72", Georgia, serif'],
    ],
    'Slab & typewriter' => [
        'rockwell'   => ['Rockwell', 'Rockwell, "Roboto Slab", Georgia, serif'],
        'clarendon'  => ['Superclarendon', 'Superclarendon, Rockwell, Georgia, serif'],
        'typewriter' => ['American Typewriter', '"American Typewriter", "Courier New", monospace'],
    ],
    'Monospace' => [
        'menlo'  => ['Menlo', 'Menlo, Monaco, monospace'],
    ],
];

/** color schemes: key => [label, theme-color]; the tokens live in style.css under [data-scheme="<key>"] */
const SCHEMES = [
    'light-colors' => ['Light Colors', '#4F46E5'],
    'light-mono'   => ['Light Monochrome', '#18181B'],
    'dark-colors'  => ['Dark Colors', '#18181B'],
    'dark-mono'    => ['Dark Monochrome', '#0F0F12'],
];

const CONFIG_DEFAULTS = ['scheme' => 'light-colors', 'font_head' => 'futura', 'font_body' => 'palatino'];


/** CSS font stack for a font key, or null for an unknown key */
function font_stack(string $key): ?string
{
    foreach (FONTS as $group) {
        if (isset($group[$key])) {
            return $group[$key][1];
        }
    }
    return null;
}

/** keep only known keys and values; anything else falls back to the default */
function clean_config(array $in): array
{
    $out = CONFIG_DEFAULTS;
    if (isset($in['scheme']) && is_string($in['scheme']) && isset(SCHEMES[$in['scheme']])) {
        $out['scheme'] = $in['scheme'];
    }
    foreach (['font_head', 'font_body'] as $k) {
        if (isset($in[$k]) && is_string($in[$k]) && font_stack($in[$k]) !== null) {
            $out[$k] = $in[$k];
        }
    }
    return $out;
}

function read_config(string $file): array
{
    $json = is_file($file) ? json_decode((string) file_get_contents($file), true) : null;
    return clean_config(is_array($json) ? $json : []);
}

/** @return list<array{path:string,name:string,registered:string,last_seen:string}> */
function read_registry(string $file): array
{
    if (!is_file($file)) {
        return [];
    }
    $rows = [];
    $h = fopen($file, 'r');
    if ($h === false) {
        return [];
    }
    $header = null;
    while (($row = fgetcsv($h, null, ',', '"', '')) !== false) {
        if ($row === [null] || $row === []) {
            continue;
        }
        if ($header === null) {
            $header = $row;
            continue;
        }
        $rows[] = [
            'path'       => (string) ($row[0] ?? ''),
            'name'       => (string) ($row[1] ?? ''),
            'registered' => (string) ($row[2] ?? ''),
            'last_seen'  => (string) ($row[3] ?? ''),
        ];
    }
    fclose($h);
    usort($rows, fn($a, $b) => strcmp($a['name'], $b['name']));
    return $rows;
}

/** Parse `key: value` lines between the first two `---` lines. YAML lists (files:) are ignored. */
function frontmatter(string $file): array
{
    $out = [];
    $fh = fopen($file, 'r');
    if ($fh === false) {
        return $out;
    }
    $inside = false;
    while (($line = fgets($fh)) !== false) {
        $line = rtrim($line, "\r\n");
        if ($line === '---') {
            if ($inside) {
                break;
            }
            $inside = true;
            continue;
        }
        if (!$inside || !preg_match('/^([A-Za-z_]+):\s*(.*)$/', $line, $m)) {
            continue;
        }
        $out[$m[1]] = trim($m[2], " \t\"'");
    }
    fclose($fh);
    return $out;
}

/** first paragraph of the item's "## Request" section, whitespace-collapsed, max 200 chars; '' when absent. Reads at most 60 lines. */
function request_peek(string $file): string
{
    $fh = fopen($file, 'r');
    if ($fh === false) {
        return '';
    }
    $in = false;
    $buf = [];
    $lines = 0;
    while (($line = fgets($fh)) !== false && ++$lines <= 60) {
        $line = trim($line);
        if (!$in) {
            $in = $line === '## Request';
            continue;
        }
        if (str_starts_with($line, '#') || ($line === '' && $buf !== [])) {
            break;
        }
        if ($line !== '') {
            $buf[] = $line;
        }
    }
    fclose($fh);
    return short((string) preg_replace('/\s+/', ' ', implode(' ', $buf)), 200);
}

/** markdown body of an item (max 200 KB) without its frontmatter and without the leading "# <title>" line */
function item_body(string $file): string
{
    $md = (string) @file_get_contents($file, false, null, 0, 204800);
    $md = str_replace("\r\n", "\n", $md);
    if (str_starts_with($md, "---\n") && ($end = strpos($md, "\n---\n", 3)) !== false) {
        $md = substr($md, $end + 5);
    }
    return (string) preg_replace('/^\s*# [^\n]*\n/', '', $md, 1);
}

/** inline markdown of one escaped-later line: `code`, **bold**, [text](http…) and [text](#anchor) */
function md_inline(string $s): string
{
    $parts = preg_split('/(`[^`]+`)/', $s, -1, PREG_SPLIT_DELIM_CAPTURE) ?: [$s];
    $h = '';
    foreach ($parts as $i => $part) {
        if ($i % 2 === 1) {
            $h .= '<code>' . e(substr($part, 1, -1)) . '</code>';
            continue;
        }
        $part = e($part);
        $part = (string) preg_replace('/\*\*(.+?)\*\*/', '<strong>$1</strong>', $part);
        // only http(s) and in-page #anchor targets become links; anything else (javascript:, file:) stays text
        $part = (string) preg_replace_callback('/\[([^\]]+)\]\(((?:[^()\s]|\([^()\s]*\))+)\)/', fn($m) => preg_match('#^(https?://|\#[a-z0-9-]+$)#i', html_entity_decode($m[2], ENT_QUOTES))
            ? '<a href="' . $m[2] . '" rel="noreferrer">' . $m[1] . '</a>'
            : $m[1], $part);
        $h .= $part;
    }
    return $h;
}

/** cells of one markdown table row: split on unescaped |, outer pipes dropped */
function md_cells(string $row): array
{
    $cells = preg_split('/(?<!\\\\)\|/', trim($row)) ?: [];
    if ($cells !== [] && trim($cells[0]) === '') {
        array_shift($cells);
    }
    if ($cells !== [] && trim(end($cells)) === '') {
        array_pop($cells);
    }
    return array_map(fn($c) => str_replace('\\|', '|', trim($c)), $cells);
}

/** a | table | block as <table> when its second row is a |---| separator, else as preformatted text */
function md_table(array $rows): string
{
    if (count($rows) < 2 || !preg_match('/^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?$/', $rows[1])) {
        return '<pre>' . e(implode("\n", $rows)) . '</pre>';
    }
    $h = '<table class="md-table"><thead><tr>';
    foreach (md_cells($rows[0]) as $c) {
        $h .= '<th>' . md_inline($c) . '</th>';
    }
    $h .= '</tr></thead><tbody>';
    foreach (array_slice($rows, 2) as $row) {
        $h .= '<tr>';
        foreach (md_cells($row) as $c) {
            $h .= '<td>' . md_inline($c) . '</td>';
        }
        $h .= '</tr>';
    }
    return $h . '</tbody></table>';
}

/**
 * minimal markdown → HTML for item bodies and the FAQ: ## / ### headings, - / 1. lists (one level), - [x] checkboxes,
 * ``` fences as preformatted text, | tables | (with a |---| row), paragraphs. Everything is escaped; no raw HTML passes through.
 * $anchors gives headings a unique id (slug of their text) for in-page links; off for kanban panels, which repeat headings.
 */
function md_html(string $md, bool $anchors = false): string
{
    $h = '';
    $para = [];
    $list = null;   // 'ul' | 'ol' | null
    $fence = null;  // lines of an open ``` block
    $table = [];
    $slugs = [];
    $flush = function () use (&$h, &$para, &$list, &$table): void {
        if ($para !== []) {
            $h .= '<p>' . md_inline(implode(' ', $para)) . '</p>';
            $para = [];
        }
        if ($list !== null) {
            $h .= '</li></' . $list . '>';
            $list = null;
        }
        if ($table !== []) {
            $h .= md_table($table);
            $table = [];
        }
    };
    foreach (explode("\n", $md) as $line) {
        if ($fence !== null) {
            if (preg_match('/^\s*```/', $line)) {
                $h .= '<pre><code>' . e(implode("\n", $fence)) . '</code></pre>';
                $fence = null;
            } else {
                $fence[] = $line;
            }
            continue;
        }
        $t = trim($line);
        if (str_starts_with($t, '```')) {
            $flush();
            $fence = [];
        } elseif ($t === '') {
            $flush();
        } elseif (preg_match('/^(#{2,6})\s+(.*)$/', $t, $m)) {
            $flush();
            $tag = strlen($m[1]) === 2 ? 'h4' : 'h5';
            $id = '';
            if ($anchors) {
                $slug = trim((string) preg_replace('/[^a-z0-9]+/', '-', strtolower($m[2])), '-') ?: 'section';
                $slugs[$slug] = ($slugs[$slug] ?? 0) + 1;
                $id = ' id="' . e($slugs[$slug] > 1 ? $slug . '-' . $slugs[$slug] : $slug) . '"';
            }
            $h .= '<' . $tag . $id . '>' . md_inline($m[2]) . '</' . $tag . '>';
        } elseif (str_starts_with($t, '|')) {
            if ($para !== [] || $list !== null) {
                $flush();
            }
            $table[] = $t;
        } elseif (preg_match('/^([-*]|\d+[.)])\s+(.*)$/', $t, $m)) {
            $type = ctype_digit($m[1][0]) ? 'ol' : 'ul';
            if ($para !== [] || $table !== [] || ($list !== null && $list !== $type)) {
                $flush();
            }
            $item = (string) preg_replace_callback('/^\[([ xX])\]\s+/', fn($c) => $c[1] === ' ' ? "\u{2610} " : "\u{2611} ", $m[2]);
            $h .= ($list === null ? '<' . $type . '><li>' : '</li><li>') . md_inline($item);
            $list = $type;
        } elseif ($list !== null && $line !== ltrim($line)) {
            $h .= ' ' . md_inline($t); // indented continuation of a list item
        } else {
            if ($list !== null || $table !== []) {
                $flush();
            }
            $para[] = $t;
        }
    }
    if ($fence !== null) {
        $h .= '<pre><code>' . e(implode("\n", $fence)) . '</code></pre>';
    }
    $flush();
    return $h;
}

/** @return list<array<string,string>> items of one stage dir, sorted by filename (= by date) */
function items(string $dir): array
{
    if (!is_dir($dir)) {
        return [];
    }
    $files = glob($dir . '/20*.md') ?: [];
    sort($files);
    $list = [];
    foreach ($files as $f) {
        $base = basename($f);
        $parts = explode('.', $base);
        $fm = frontmatter($f);
        $list[] = [
            'file'  => $f,
            'base'  => $base,
            'date'  => substr($base, 0, 10),
            'type'  => $parts[1] ?? '?',
            'size'  => $fm['size'] ?? '?',
            'title' => $fm['title'] ?? preg_replace('/^.*?\..*?\./', '', substr($base, 0, -3)),
            'confidence' => $fm['confidence'] ?? '',
            'plan_at' => $fm['plan_at'] ?? '',
            'busy_at' => $fm['busy_at'] ?? '',
            'done_at' => $fm['done_at'] ?? '',
            'skipped_at' => $fm['skipped_at'] ?? '',
            'someday_at' => $fm['someday_at'] ?? '',
            'waiting_on' => $fm['waiting_on'] ?? '',
            'waiting_since' => $fm['waiting_since'] ?? '',
        ];
    }
    return $list;
}

/** "3 days ago" style relative time */
function ago(int $ts, ?int $now = null): string
{
    $d = max(0, ($now ?? time()) - $ts);
    foreach ([[31536000, 'year'], [2592000, 'month'], [604800, 'week'], [86400, 'day'], [3600, 'hour'], [60, 'minute']] as [$sec, $unit]) {
        if ($d >= $sec) {
            $n = intdiv($d, $sec);
            return $n . ' ' . $unit . ($n === 1 ? '' : 's') . ' ago';
        }
    }
    return 'just now';
}

/** timestamp of the repo's last git activity (commit, checkout, …) read from .git/logs/HEAD; git itself is never run */
function git_last_activity(string $repo): ?int
{
    $git = $repo . '/.git';
    if (is_file($git) && preg_match('/^gitdir:\s*(.+)$/m', (string) file_get_contents($git), $m)) {
        $git = str_starts_with($m[1], '/') ? trim($m[1]) : $repo . '/' . trim($m[1]); // worktree / submodule
    }
    $log = $git . '/logs/HEAD';
    if (!is_file($log) || ($size = filesize($log)) === 0) {
        return null;
    }
    $fh = fopen($log, 'r');
    if ($fh === false) {
        return null;
    }
    fseek($fh, max(0, $size - 4096));
    $tail = (string) stream_get_contents($fh);
    fclose($fh);
    $lines = array_values(array_filter(explode("\n", $tail)));
    // reflog line: <old> <new> <name> <email> <unix-ts> <tz>\t<message>
    return preg_match('/> (\d{9,11}) [+-]\d{4}\t/', (string) end($lines), $m) ? (int) $m[1] : null;
}

/**
 * last activity of a busy item: the latest of the item file's mtime, its busy_at date and the repo's last git activity
 * @return array{ts:int,why:string}
 */
function last_activity(array $item, ?int $gitTs): array
{
    $cands = ['item file edited' => (int) filemtime($item['file'])];
    if ($item['busy_at'] !== '' && ($t = strtotime($item['busy_at'])) !== false) {
        $cands['started'] = $t;
    }
    if ($gitTs !== null) {
        $cands['last git activity in repo'] = $gitTs;
    }
    arsort($cands);
    $why = [];
    foreach ($cands as $label => $t) {
        $why[] = $label . ': ' . date('Y-m-d H:i', $t);
    }
    return ['ts' => reset($cands), 'why' => implode(' · ', $why)];
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function short(string $title, int $max = 48): string
{
    $title = trim($title);
    if (mb_strlen($title) <= $max) {
        return $title;
    }
    return rtrim(mb_substr($title, 0, $max - 1)) . '…';
}

/** compact list of items: ID badge + shortened title, linking to the file */
/** "waiting on" note of a busy item marked with /fodo:wait, or '' */
function waiting_html(array $it): string
{
    if (($it['waiting_on'] ?? '') === '') {
        return '';
    }
    return ' <small class="waiting-on">⏸ waiting on: ' . e($it['waiting_on'])
        . ($it['waiting_since'] !== '' ? ' · since ' . e($it['waiting_since']) : '') . '</small>';
}

/** extra class for a waiting busy item ('' or ' item-waiting'; plain .waiting belongs to the agents page) */
function waiting_cls(array $it): string
{
    return ($it['waiting_on'] ?? '') !== '' ? ' item-waiting' : '';
}

function render_list(array $items, string $prefix, string $stage): string
{
    if ($items === []) {
        return '<p class="empty">none</p>';
    }
    $h = '<ul class="items">';
    $n = 0;
    foreach ($items as $it) {
        $n++;
        $w = $stage === 'busy' ? waiting_cls($it) : '';
        $h .= '<li class="' . e($stage) . $w . '"><mark class="stage-' . e($stage) . $w . '">' . e($prefix . $n) . '</mark> '
            . '<a href="file://' . e($it['file']) . '" title="' . e($it['title'] . ' — ' . $it['base']) . '">' . e(short($it['title'])) . '</a>'
            . ' <small class="type type-' . e($it['type']) . '">' . e($it['type']) . '</small>'
            . ($stage === 'busy' ? waiting_html($it) : '') . '</li>';
    }
    return $h . '</ul>';
}

/** full-width table of items for the repo detail page (full titles, size, dates) */
function render_table(array $items, string $prefix, string $stage): string
{
    if ($items === []) {
        return '<p class="empty">none</p>';
    }
    $extra = ['plan' => 'Confidence', 'busy' => 'Since', 'done' => 'Done', 'skipped' => 'Skipped', 'someday' => 'Parked'][$stage] ?? '';
    $h = '<table class="detail"><thead><tr><th class="c-id">ID</th><th class="c-date">Created</th><th class="c-type">Type</th><th class="c-size">Size</th>'
       . ($extra !== '' ? '<th class="c-extra">' . e($extra) . '</th>' : '')
       . '<th class="c-title">Title</th><th class="c-file">File</th></tr></thead><tbody>';
    $n = 0;
    foreach ($items as $it) {
        $n++;
        $val = match ($stage) {
            'plan'    => $it['confidence'] !== '' ? $it['confidence'] . '/10' : '?',
            'busy'    => $it['busy_at'],
            'done'    => $it['done_at'],
            'skipped' => $it['skipped_at'],
            'someday' => $it['someday_at'],
            default   => '',
        };
        $h .= '<tr class="' . e($stage) . '">'
            . '<td data-label="ID"><mark class="stage-' . e($stage) . '">' . e($prefix !== '' ? $prefix . $n : (string) $n) . '</mark></td>'
            . '<td data-label="Created">' . e($it['date']) . '</td>'
            . '<td data-label="Type"><small class="type type-' . e($it['type']) . '">' . e($it['type']) . '</small></td>'
            . '<td data-label="Size">' . e($it['size']) . '</td>'
            . ($extra !== '' ? '<td data-label="' . e($extra) . '">' . e($val) . '</td>' : '')
            . '<td data-label="Title"><a href="file://' . e($it['file']) . '">' . e($it['title']) . '</a>' . ($stage === 'busy' ? waiting_html($it) : '') . '</td>'
            . '<td data-label="File"><code>' . e($it['base']) . '</code></td></tr>';
    }
    return $h . '</tbody></table>';
}

/** side panel with one item's facts and rendered body; shown by CSS when its id is the URL fragment */
function render_item_detail(string $anchor, string $id, string $stage, array $it, array $facts, string $w): string
{
    $h = '<article class="card peek item-detail ' . e($stage) . $w . '" id="' . e($anchor) . '">'
       . '<div class="head"><h2><mark class="stage-' . e($stage) . $w . '">' . e($id) . '</mark>' . e($it['title']) . '</h2>'
       . '<a class="close" href="#" aria-label="Close">&times;</a>'
       . '<small>' . e($it['type']) . ' · ' . e($it['size']) . ($it['confidence'] !== '' ? ' · ' . e($it['confidence']) . '/10' : '') . '</small></div>'
       . '<div class="body"><dl class="peek-meta">';
    foreach ($facts as [$label, $html]) {
        $h .= '<dt>' . e($label) . '</dt><dd>' . $html . '</dd>';
    }
    return $h . '</dl><div class="md">' . md_html(item_body($it['file'])) . '</div></div></article>';
}

/**
 * read-only kanban board for the repo detail page: one column per stage in lifecycle order, compact cards
 * linking to #<ID>; the matching detail panel (facts, next /fodo: command, rendered body) opens beside the board.
 * Done/skipped show the 10 most recent.
 */
function render_kanban(array $data, array $stages, ?int $gitTs, string $tableUrl): string
{
    $dates = ['someday_at' => 'Parked', 'plan_at' => 'Planned', 'busy_at' => 'Started', 'done_at' => 'Done', 'skipped_at' => 'Skipped'];
    $h = '<div class="kanban">';
    $panels = '';
    foreach (['someday', 'planned', 'plan', 'busy', 'done', 'skipped'] as $stage) { // someday sits beside the backlog
        if (!isset($stages[$stage])) {
            continue;
        }
        $prefix = $stages[$stage]['prefix'];
        $all = $data[$stage];
        $list = [];
        foreach ($all as $i => $it) {
            $list[] = [$prefix . ($i + 1), $it]; // same positional IDs as render_table()
        }
        $hidden = 0;
        if ($stage === 'done' || $stage === 'skipped') {
            $hidden = max(0, count($list) - 10);
            $list = array_reverse(array_slice($list, -10));
        }
        $h .= '<section class="col ' . e($stage) . '"><h3 class="overline ' . e($stage) . '">' . e($stages[$stage]['label'])
            . ' <small>(' . count($all) . ')</small></h3>';
        if ($list === []) {
            $h .= '<p class="empty">none</p>';
        }
        foreach ($list as [$id, $it]) {
            // done and skipped IDs are bare numbers like the backlog's, so their anchors carry the stage
            $anchor = $prefix === '' && $stage !== 'planned' ? $stage . '-' . $id : $id;
            $w = $stage === 'busy' ? waiting_cls($it) : '';
            $facts = [['File', '<code>' . e($it['base']) . '</code>'], ['Created', e($it['date'])]];
            foreach ($dates as $key => $label) {
                if ($it[$key] !== '') {
                    $facts[] = [$label, e($it[$key])];
                }
            }
            if ($stage === 'busy') {
                $facts[] = ['Last activity', e(last_activity($it, $gitTs)['why'])];
                if ($w !== '') {
                    $facts[] = ['Waiting on', e($it['waiting_on'] . ($it['waiting_since'] !== '' ? ' since ' . $it['waiting_since'] : ''))];
                }
            }
            $next = match ($stage) {
                'planned' => ['/fodo:plan ' . $id, '/fodo:start ' . $id],
                'plan'    => ['/fodo:start ' . $id],
                'busy'    => [$w !== '' ? '/fodo:wait ' . $id . ' resume' : '/fodo:done ' . $id],
                'someday' => ['/fodo:someday ' . $id . ' back'],
                default   => [],
            };
            if ($next !== []) {
                $facts[] = ['Next', implode(' or ', array_map(fn($c) => '<code>' . e($c) . '</code>', $next))];
            }
            $panels .= render_item_detail($anchor, $id, $stage, $it, $facts, $w);
            $h .= '<article class="kcard ' . e($stage) . $w . '">'
                . '<div class="meta"><mark class="stage-' . e($stage) . $w . '">' . e($id) . '</mark>'
                . '<small class="type type-' . e($it['type']) . '">' . e($it['type']) . '</small>'
                . '<span class="size">' . e($it['size']) . '</span>'
                . ($it['confidence'] !== '' ? '<span class="conf">' . e($it['confidence']) . '/10</span>' : '')
                . '<time>' . e($it['date']) . '</time></div>'
                . '<a class="title" href="#' . e($anchor) . '">' . e($it['title']) . '</a>'
                . ($stage === 'busy' ? waiting_html($it) : '') . '</article>';
        }
        if ($hidden > 0) {
            $h .= '<p class="more"><a href="' . e($tableUrl) . '">+' . $hidden . ' older, see table view</a></p>';
        }
        $h .= '</section>';
    }
    return '<div class="board">' . $h . '</div><div class="item-details">' . $panels . '</div></div>';
}

/**
 * live Claude Code sessions: every ~/.claude/sessions/<pid>.json whose process still exists.
 * These files are Claude Code internals; anything unexpected is skipped, so a format change just hides the badges.
 * @return list<array{pid:int,cwd:string,name:string,status:string,updated:int}>
 */
function agent_sessions(string $dir): array
{
    if (!is_dir($dir) || !function_exists('posix_kill')) {
        return [];
    }
    $out = [];
    foreach (glob($dir . '/*.json') ?: [] as $f) {
        $j = json_decode((string) @file_get_contents($f), true);
        if (!is_array($j) || !is_int($j['pid'] ?? null) || !is_string($j['cwd'] ?? null)) {
            continue;
        }
        // signal 0 only checks that the process exists; EPERM (1) means it exists but belongs to someone else
        if (!posix_kill($j['pid'], 0) && posix_get_last_error() !== 1) {
            continue;
        }
        $out[] = [
            'pid'     => $j['pid'],
            'cwd'     => $j['cwd'],
            'name'    => is_string($j['name'] ?? null) ? $j['name'] : 'pid ' . $j['pid'],
            'status'  => ($j['status'] ?? '') === 'busy' ? 'working' : 'idle',
            'updated' => intdiv((int) ($j['statusUpdatedAt'] ?? $j['updatedAt'] ?? 0), 1000),
        ];
    }
    return $out;
}

/** agent badge for the sessions of one repo ('' when there are none): "working" if any session works, else "idle" */
function render_agents(array $sessions): string
{
    if ($sessions === []) {
        return '';
    }
    $working = array_filter($sessions, fn($s) => $s['status'] === 'working');
    $state = $working !== [] ? 'working' : 'idle';
    $tips = array_map(fn($s) => 'Claude Code "' . $s['name'] . '" ' . $s['status'] . ($s['updated'] > 0 ? ' since ' . ago($s['updated']) : '') . ' — ' . $s['cwd'], $sessions);
    $label = (count($sessions) > 1 ? count($sessions) . ' agents ' : 'agent ') . $state;
    return '<a href="/agents" class="agent ' . $state . '" title="' . e(implode("\n", $tips)) . '"><i></i>' . e($label) . '</a>';
}

/** agent view state groups, in display order */
const AGENT_GROUPS = ['input' => 'Needs input', 'working' => 'Working', 'idle' => 'Idle', 'completed' => 'Completed'];

/** state group of one `claude agents --json` entry; first match wins */
function agent_state(array $j): string
{
    $state  = is_string($j['state'] ?? null) ? $j['state'] : '';
    $status = is_string($j['status'] ?? null) ? $j['status'] : '';
    return match (true) {
        $state === 'blocked' || $status === 'waiting'              => 'input',
        $state === 'working' || $status === 'busy'                 => 'working',
        in_array($state, ['done', 'failed', 'stopped'], true)      => 'completed',
        default                                                    => 'idle',
    };
}

/** the absolute claude path that /fodo:valet stored, or '' when missing or not executable */
function stored_claude_bin(string $file): string
{
    $bin = is_file($file) ? trim((string) @file_get_contents($file)) : '';
    return $bin !== '' && is_executable($bin) ? $bin : '';
}

/**
 * every Claude Code session, from `claude agents --json --all` (run without a shell, with a timeout)
 * @return array{sessions: list<array<string,mixed>>, error: ?string}
 */
function agents_cli(string $bin, int $timeout = 5): array
{
    $notFound = 'claude CLI not found (run /fodo:valet to store its path, put claude on the PATH of the dashboard server, or set FODO_CLAUDE_BIN).';
    $proc = @proc_open([$bin, 'agents', '--json', '--all'], [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
    if (!is_resource($proc)) {
        return ['sessions' => [], 'error' => $notFound];
    }
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);
    $out = $err = '';
    $deadline = microtime(true) + $timeout;
    while (true) {
        $out .= (string) stream_get_contents($pipes[1]);
        $err .= (string) stream_get_contents($pipes[2]);
        if (feof($pipes[1]) && feof($pipes[2])) {
            break;
        }
        if (microtime(true) > $deadline) {
            proc_terminate($proc);
            fclose($pipes[1]);
            fclose($pipes[2]);
            proc_close($proc);
            return ['sessions' => [], 'error' => 'claude agents timed out after ' . $timeout . ' s.'];
        }
        usleep(20000);
    }
    fclose($pipes[1]);
    fclose($pipes[2]);
    $code = proc_close($proc);
    if ($code === 127) {
        return ['sessions' => [], 'error' => $notFound];
    }
    if ($code !== 0) {
        $first = trim((string) strtok(trim($err), "\n"));
        return ['sessions' => [], 'error' => 'claude agents failed (exit ' . $code . ')' . ($first !== '' ? ': ' . $first : '.')];
    }
    $json = json_decode($out, true);
    if (!is_array($json) || !array_is_list($json)) {
        return ['sessions' => [], 'error' => 'claude agents returned unexpected output.'];
    }
    $sessions = [];
    foreach ($json as $j) {
        if (!is_array($j) || !is_string($j['cwd'] ?? null)) {
            continue;
        }
        $str = fn(string $k) => is_scalar($j[$k] ?? null) ? (string) $j[$k] : '';
        $name = $str('name') ?: ($str('id') ?: ($str('pid') !== '' ? 'pid ' . $str('pid') : basename($j['cwd'])));
        $sessions[] = [
            'sessionId'  => $str('sessionId'),
            'id'         => $str('id'),
            'name'       => $name,
            'cwd'        => $j['cwd'],
            'kind'       => $str('kind'),
            'state'      => $str('state'),
            'status'     => $str('status'),
            'waitingFor' => $str('waitingFor'),
            'started'    => intdiv((int) ($j['startedAt'] ?? 0), 1000),
            'group'      => agent_state($j),
            'sub'        => $str('state') ?: $str('status'),
        ];
    }
    usort($sessions, fn($a, $b) => $b['started'] <=> $a['started']);
    return ['sessions' => $sessions, 'error' => null];
}

/** the registered repo (block) that contains $cwd; the longest repo path wins */
function repo_for_cwd(array $blocks, string $cwd): ?array
{
    $cwd = realpath($cwd) ?: $cwd; // repo roots are realpaths (e.g. /var → /private/var on macOS)
    $best = null;
    foreach ($blocks as $b) {
        $root = dirname($b['todo'], 2);
        if (($cwd === $root || str_starts_with($cwd, $root . '/')) && ($best === null || strlen($root) > strlen(dirname($best['todo'], 2)))) {
            $best = $b;
        }
    }
    return $best;
}

/**
 * the busy item a repo is working on: docs/todo/.current if it is still busy, else the only busy item
 * @return ?array{id:string,title:string,file:string}
 */
function current_busy(array $block): ?array
{
    $busy = $block['data']['busy'];
    $cur = trim((string) @file_get_contents($block['todo'] . '/.current'));
    foreach ($busy as $n => $it) {
        if ($cur !== '' && $it['base'] === $cur) {
            return ['id' => 'B' . ($n + 1), 'title' => $it['title'], 'file' => $it['file']];
        }
    }
    return count($busy) === 1 ? ['id' => 'B1', 'title' => $busy[0]['title'], 'file' => $busy[0]['file']] : null;
}

/** cut long transcript text for display */
function clip(string $s, int $max = 2000): string
{
    $s = trim($s);
    return mb_strlen($s) > $max ? rtrim(mb_substr($s, 0, $max - 1)) . '…' : $s;
}

/**
 * transcript file of a session and the whole lines of its last 512 KB
 * @return array{file:?string,lines:list<string>}
 */
function transcript_tail(string $projectsDir, string $sessionId): array
{
    $file = (glob($projectsDir . '/*/' . $sessionId . '.jsonl') ?: [])[0] ?? null;
    if ($file === null || ($fh = @fopen($file, 'r')) === false) {
        return ['file' => null, 'lines' => []];
    }
    $size = (int) filesize($file);
    fseek($fh, max(0, $size - 524288));
    $tail = (string) stream_get_contents($fh);
    fclose($fh);
    $lines = explode("\n", $tail);
    if ($size > 524288) {
        array_shift($lines); // partial first line
    }
    return ['file' => $file, 'lines' => $lines];
}

/** last prompt of a session (only the last-prompt lines are decoded, so this is cheap enough per row), or null */
function last_prompt(string $projectsDir, string $sessionId): ?string
{
    $lines = transcript_tail($projectsDir, $sessionId)['lines'];
    for ($i = count($lines) - 1; $i >= 0; $i--) {
        if (!str_contains($lines[$i], '"last-prompt"')) {
            continue;
        }
        $j = json_decode($lines[$i], true);
        if (is_array($j) && ($j['type'] ?? null) === 'last-prompt' && is_string($j['lastPrompt'] ?? null)) {
            return $j['lastPrompt'];
        }
    }
    return null;
}

/**
 * AI title, last prompt and last assistant text reply of a session, from the last 512 KB of its transcript
 * @return array{title:?string,prompt:?string,reply:?string,file:?string}
 */
function transcript_peek(string $projectsDir, string $sessionId): array
{
    ['file' => $file, 'lines' => $lines] = transcript_tail($projectsDir, $sessionId);
    $peek = ['title' => null, 'prompt' => null, 'reply' => null, 'file' => $file];
    foreach ($lines as $line) {
        $j = json_decode($line, true);
        if (!is_array($j)) {
            continue;
        }
        $type = $j['type'] ?? null;
        if ($type === 'ai-title' && is_string($j['aiTitle'] ?? null)) {
            $peek['title'] = clip($j['aiTitle'], 200);
        } elseif ($type === 'last-prompt' && is_string($j['lastPrompt'] ?? null)) {
            $peek['prompt'] = clip($j['lastPrompt']);
        } elseif ($type === 'assistant' && is_array($j['message']['content'] ?? null)) {
            $text = [];
            foreach ($j['message']['content'] as $c) {
                if (is_array($c) && ($c['type'] ?? null) === 'text' && is_string($c['text'] ?? null)) {
                    $text[] = $c['text'];
                }
            }
            if ($text !== [] && trim(implode('', $text)) !== '') {
                $peek['reply'] = clip(implode("\n\n", $text));
            }
        }
    }
    return $peek;
}

/** one session row on /agents */
function render_agent_row(array $s, ?array $block, ?array $busy, bool $selected, string $by, ?string $prompt = null): string
{
    // the fodo logo marks sessions whose last prompt was a /fodo:* command
    $mark = $prompt !== null && str_starts_with(ltrim($prompt), '/fodo:')
          ? ' <img class="fodo-mark" src="icon.svg" alt="fodo" title="' . e(short(ltrim($prompt), 80)) . '" width="16" height="16">'
          : '';
    $h = '<li class="agent-row state-' . e($s['group']) . ' sub-' . e($s['sub']) . ($selected ? ' selected' : '') . '">'
       . '<i class="dot" title="' . e($s['sub'] !== '' ? $s['sub'] : $s['group']) . '"></i>'
       . ($s['sessionId'] !== ''
           ? '<a class="name" href="/agents?s=' . e($s['sessionId']) . $by . '">' . e($s['name']) . $mark . '</a>'
           : '<span class="name">' . e($s['name']) . '</span>');
    if ($block !== null) {
        $h .= '<a class="repo" href="./?repo=' . $block['idx'] . '" title="' . e($s['cwd']) . '">'
            . ($block['icon'] !== null ? '<img class="favicon" src="' . e($block['icon']) . '" alt="" width="16" height="16">' : '')
            . e($block['repo']['name']) . '</a>';
    } else {
        $h .= '<span class="repo other" title="' . e($s['cwd']) . '">' . e(basename($s['cwd'])) . '</span>';
    }
    if ($busy !== null) {
        $h .= '<span class="item"><mark class="stage-busy">' . e($busy['id']) . '</mark> <a href="file://' . e($busy['file']) . '">' . e(short($busy['title'], 60)) . '</a></span>';
    }
    if ($s['waitingFor'] !== '') {
        $h .= '<span class="waiting">' . e(short($s['waitingFor'], 80)) . '</span>';
    }
    if ($s['kind'] !== '') {
        $h .= '<small class="kind">' . e($s['kind']) . '</small>';
    }
    if ($s['started'] > 0) {
        $h .= '<time datetime="' . e(date('c', $s['started'])) . '" title="started ' . e(date('Y-m-d H:i', $s['started'])) . '">' . e(ago($s['started'])) . '</time>';
    }
    return $h . '</li>';
}

/** one repo card for the overview grid */
function render_card(array $b, bool $showAll): string
{
    $r = $b['repo'];
    $h = '<article class="card repo"><div class="head">'
       . '<h2 title="' . e($r['path']) . '"><a href="./?repo=' . $b['idx'] . ($showAll ? '&amp;all=1' : '') . '">'
       . ($b['icon'] !== null ? '<img class="favicon" src="' . e($b['icon']) . '" alt="" width="20" height="20">' : '')
       . e($r['name']) . '</a>'
       . ($b['laravel'] ? ' <img class="laravel" src="laravel.svg" alt="Laravel" title="Laravel project (artisan found)" width="16" height="16">' : '')
       . ' <span class="agent-slot" data-idx="' . $b['idx'] . '">' . render_agents($b['agents']) . '</span>'
       . '</h2><small title="' . e($r['path']) . '">' . e($r['path']) . '</small></div><div class="body">';
    foreach (['busy' => ['B', 'Busy'], 'plan' => ['P', 'Plan']] as $stage => [$prefix, $label]) {
        if ($b['data'][$stage] !== []) {
            $h .= '<h3 class="overline ' . $stage . '">' . $label . ' <small>(' . count($b['data'][$stage]) . ')</small></h3>'
                . render_list($b['data'][$stage], $prefix, $stage);
        }
    }
    $h .= '<div class="totals"><span><strong>' . count($b['data']['planned']) . '</strong> in backlog</span>';
    if ($showAll) {
        $h .= '<span><strong>' . count($b['data']['someday']) . '</strong> someday</span>'
            . '<span><strong>' . count($b['data']['done']) . '</strong> done</span>'
            . '<span><strong>' . count($b['data']['skipped']) . '</strong> skipped</span>';
    }
    return $h . '</div></div></article>';
}

/** first favicon-like file found in the repo (common web-app locations), or null */
function find_favicon(string $repo): ?string
{
    $candidates = [
        'public/favicon.ico', 'public/favicon.svg', 'public/favicon.png',
        'public/apple-touch-icon.png', 'public/images/favicon.ico', 'public/img/favicon.ico',
        'favicon.ico', 'favicon.svg', 'favicon.png',
        'static/favicon.ico', 'assets/favicon.ico', 'src/favicon.ico', 'docs/favicon.ico',
        'resources/favicon.ico', 'web/favicon.ico', 'www/favicon.ico', 'dist/favicon.ico',
    ];
    foreach ($candidates as $c) {
        $f = $repo . '/' . $c;
        if (is_file($f) && filesize($f) > 0) {
            return $f;
        }
    }
    return null;
}

$repos = read_registry($registry);

// ?icon=<n> streams the favicon of the n-th registered repo (only files found by find_favicon)
if (isset($_GET['icon'])) {
    $i = (int) $_GET['icon'];
    $real = isset($repos[$i]) ? realpath($repos[$i]['path']) : false;
    $icon = $real !== false ? find_favicon($real) : null;
    if ($icon === null || !str_starts_with(realpath($icon) ?: '', $real)) {
        http_response_code(404);
        exit;
    }
    $ext = strtolower(pathinfo($icon, PATHINFO_EXTENSION));
    $mime = ['ico' => 'image/x-icon', 'png' => 'image/png', 'svg' => 'image/svg+xml'][$ext] ?? 'application/octet-stream';
    $mtime = filemtime($icon) ?: 0;
    $etag  = '"' . $mtime . '-' . filesize($icon) . '"';
    // the URL carries ?v=<mtime>, so a changed file gets a new URL; still answer 304 when nothing changed
    if (($_SERVER['HTTP_IF_NONE_MATCH'] ?? '') === $etag) {
        http_response_code(304);
        exit;
    }
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . (string) filesize($icon));
    header('ETag: ' . $etag);
    header('Last-Modified: ' . gmdate('D, d M Y H:i:s', $mtime) . ' GMT');
    header('Cache-Control: private, no-cache');
    readfile($icon);
    exit;
}

// /config: GET shows the form, POST saves it (same-origin only) and redirects back
$config      = read_config($configFile);
$configError = null;
if ($configView && $urlPath !== '/config') {
    header('Location: /config', true, 301);
    exit;
}
if ($faqView && $urlPath !== '/faq') {
    header('Location: /faq', true, 301);
    exit;
}
if ($configView && ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? $_SERVER['HTTP_REFERER'] ?? '';
    if ($origin !== '' && parse_url($origin, PHP_URL_HOST) !== parse_url('//' . ($_SERVER['HTTP_HOST'] ?? ''), PHP_URL_HOST)) {
        http_response_code(403);
        exit('cross-origin request refused');
    }
    $new = isset($_POST['reset']) ? CONFIG_DEFAULTS : clean_config($_POST);
    if ((is_dir($dataDir) || @mkdir($dataDir, 0755, true))
        && @file_put_contents($configFile, json_encode($new, JSON_PRETTY_PRINT) . "\n", LOCK_EX) !== false) {
        header('Location: /config?saved=1', true, 303);
        exit;
    }
    $config      = $new;
    $configError = 'Could not write ' . $configFile . '.';
}

$stages = [
    'busy'    => ['label' => 'Busy',    'dir' => 'busy',    'prefix' => 'B', 'extra' => 'busy_at'],
    'plan'    => ['label' => 'Plan',    'dir' => 'plan',    'prefix' => 'P', 'extra' => 'confidence'],
    'planned' => ['label' => 'Backlog', 'dir' => '',        'prefix' => '',  'extra' => ''],
];
if ($showAll) {
    $stages['someday'] = ['label' => 'Someday', 'dir' => 'someday', 'prefix' => 'S', 'extra' => 'someday_at'];
    $stages['done']    = ['label' => 'Done',    'dir' => 'done',    'prefix' => '', 'extra' => 'done_at'];
    $stages['skipped'] = ['label' => 'Skipped', 'dir' => 'skipped', 'prefix' => '', 'extra' => 'skipped_at'];
}

$missing = [];
$blocks = [];
$totals = array_fill_keys(array_keys($stages), 0);
foreach ($repos as $idx => $r) {
    $real = realpath($r['path']);
    $todo = $real !== false ? $real . '/docs/todo' : false;
    if ($todo === false || !is_dir($todo)) {
        $missing[] = $r;
        continue;
    }
    $data = [];
    foreach ($stages as $key => $st) {
        $data[$key] = items($st['dir'] === '' ? $todo : $todo . '/' . $st['dir']);
        $totals[$key] += count($data[$key]);
    }
    $blocks[] = ['idx' => $idx, 'repo' => $r, 'todo' => $todo, 'data' => $data, 'icon' => ($fav = find_favicon($real)) !== null ? './?icon=' . $idx . '&v=' . (filemtime($fav) ?: 0) : null,
                 'laravel' => is_file($real . '/artisan')];
}

// live agent sessions, matched to the registered repo that contains their working directory (longest path wins)
$agentsByIdx = [];
$agentsElsewhere = [];
foreach (agent_sessions($sessionDir) as $sess) {
    $best = repo_for_cwd($blocks, $sess['cwd']);
    if ($best !== null) {
        $agentsByIdx[$best['idx']][] = $sess;
    } else {
        $agentsElsewhere[] = $sess;
    }
}
foreach ($blocks as $i => $b) {
    $blocks[$i]['agents'] = $agentsByIdx[$b['idx']] ?? [];
}
$agentCount = count($agentsElsewhere) + array_sum(array_map('count', $agentsByIdx));

// /agents: every session from the claude CLI, grouped by state (or by repo with ?by=repo); ?s=<sessionId> opens the peek panel
$agentGroups = [];
$agentCounts = array_fill_keys(array_keys(AGENT_GROUPS), 0);
$agentsError = null;
$peekSession = null;
$peek        = null;
$byRepo      = ($_GET['by'] ?? '') === 'repo';
$byParam     = $byRepo ? '&amp;by=repo' : '';
if ($agentsView) {
    if ($urlPath !== '/agents') {
        header('Location: /agents' . (($q = (string) ($_SERVER['QUERY_STRING'] ?? '')) !== '' ? '?' . $q : ''), true, 301);
        exit;
    }
    $res = agents_cli($claudeBin);
    $agentsError = $res['error'];
    $want = is_string($_GET['s'] ?? null) && preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/', $_GET['s']) ? $_GET['s'] : null;
    $byKey = [];
    foreach ($res['sessions'] as $s) {
        $block = repo_for_cwd($blocks, $s['cwd']);
        $row = ['s' => $s, 'block' => $block, 'busy' => $block !== null ? current_busy($block) : null,
                'prompt' => $s['sessionId'] !== '' ? last_prompt($claudeDir . '/projects', $s['sessionId']) : null];
        $agentCounts[$s['group']]++;
        if ($want !== null && $s['sessionId'] === $want) {
            $peekSession = $row;
        }
        if ($byRepo) {
            $key = $block !== null ? $block['repo']['name'] : "\u{10FFFF}"; // sessions outside registered repos go last
            $byKey[$key][] = $row;
        } else {
            $byKey[$s['group']][] = $row;
        }
    }
    if ($byRepo) {
        ksort($byKey, SORT_NATURAL | SORT_FLAG_CASE);
        foreach ($byKey as $key => $rows) {
            $agentGroups[] = ['label' => $key === "\u{10FFFF}" ? 'Other folders' : $key, 'rows' => $rows];
        }
    } else {
        foreach (AGENT_GROUPS as $key => $label) {
            if (isset($byKey[$key])) {
                $agentGroups[] = ['label' => $label, 'key' => $key, 'rows' => $byKey[$key]];
            }
        }
    }
    // only sessions the CLI just listed can be peeked at, so ?s= never opens an arbitrary file
    if ($peekSession !== null) {
        $peek = transcript_peek($claudeDir . '/projects', $peekSession['s']['sessionId']);
    }
}

// every busy item over all repos, most recently active first
$busyAll = [];
foreach ($blocks as $b) {
    $gitTs = git_last_activity(dirname($b['todo'], 2));
    foreach ($b['data']['busy'] as $n => $it) {
        $busyAll[] = $it + ['id' => 'B' . ($n + 1), 'block' => $b, 'activity' => last_activity($it, $gitTs)];
    }
}
// waiting items (/fodo:wait) after the active ones, each group most recently active first
usort($busyAll, fn($a, $b) => [$a['waiting_on'] !== '', $b['activity']['ts']] <=> [$b['waiting_on'] !== '', $a['activity']['ts']]);

// repo detail page (?repo=<n>)
$detail = null;
if ($repoView !== null) {
    foreach ($blocks as $b) {
        if ($b['idx'] === $repoView) {
            $detail = $b;
            break;
        }
    }
}
$toggleBase = $detail !== null ? './?repo=' . $detail['idx'] . ($tableView ? '&view=table' : '') : './';
$toggleAll  = $detail !== null ? $toggleBase . '&all=1' : './?all=1';

// repos with at least one busy or plan item come first, then repos with only backlog (planned) items after a divider;
// repos with nothing in backlog (planned), plan or busy are hidden behind a "show" button
$active = array_values(array_filter($blocks, fn($b) => $b['data']['busy'] !== [] || $b['data']['plan'] !== []));
$idle   = array_values(array_filter($blocks, fn($b) => $b['data']['busy'] === [] && $b['data']['plan'] === [] && $b['data']['planned'] !== []));
$empty  = array_values(array_filter($blocks, fn($b) => $b['data']['busy'] === [] && $b['data']['plan'] === [] && $b['data']['planned'] === []));
?>
<!doctype html>
<html lang="en" data-scheme="<?= e($config['scheme']) ?>" style="--font:<?= e((string) font_stack($config['font_body'])) ?>; --font-head:<?= e((string) font_stack($config['font_head'])) ?>">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<?php if (!$configView && !$faqView): ?><meta http-equiv="refresh" content="<?= $agentsView ? 15 : 60 ?>"><?php /* reload: /agents every 15 s, the overview every minute (counts, busy panel, agent badges) */ ?><?php endif; ?>
<title>fodo &bull; <?= e(preg_replace('/\.local$/', '', php_uname('n'))) ?><?= $configView ? ' &bull; config' : ($faqView ? ' &bull; faq' : ($agentsView ? ' &bull; agents' : ($detail !== null ? ' &bull; ' . e($detail['repo']['name']) : ''))) ?></title>
<link rel="icon" type="image/svg+xml" href="icon.svg">
<meta name="theme-color" content="<?= e(SCHEMES[$config['scheme']][1]) ?>">
<link rel="stylesheet" href="style.css?v=<?= e((string) (filemtime(__DIR__ . '/style.css') ?: 0)) ?>">
</head>
<body>
<header class="topbar">
  <a href="./" class="logo"><img src="icon.svg" alt="" width="24" height="24">fodo</a>
  <span class="counts">
    <?php foreach ($stages as $key => $st): ?>
      <mark class="stage-<?= e($key) ?>"><?= e($st['label']) ?> <?= $totals[$key] ?></mark>
    <?php endforeach; ?>
  </span>
  <?php if ($showAll): ?>
    <a href="<?= e($toggleBase) ?>" class="btn">Hide someday / done / skipped</a>
  <?php else: ?>
    <a href="<?= e($toggleAll) ?>" class="btn">Show someday / done / skipped</a>
  <?php endif; ?>
  <a href="/agents" class="btn agents-link" title="Claude Code sessions on this machine"<?= $agentsView ? ' aria-current="page"' : '' ?>>Agents<?= $agentCount > 0 ? ' <small>' . $agentCount . '</small>' : '' ?></a>
  <a href="/faq" class="settings" title="FAQ: why docs/todo/, the happy path, every command" aria-label="FAQ"<?= $faqView ? ' aria-current="page"' : '' ?>>
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/></svg>
  </a>
  <a href="/config" class="settings" title="Fonts and color scheme" aria-label="Settings"<?= $configView ? ' aria-current="page"' : '' ?>>
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
  </a>
</header>

<main class="container">
<?php if ($configView): ?>
  <p class="crumbs"><a href="/">&larr; all repos</a></p>
  <?php if ($configError !== null): ?>
    <p class="notice error"><?= e($configError) ?></p>
  <?php elseif (isset($_GET['saved'])): ?>
    <p class="notice">Saved to <code><?= e($configFile) ?></code>.</p>
  <?php endif; ?>
  <form method="post" action="/config" class="config">
    <p class="config-meta">Registry: <code><?= e($registry) ?></code></p>
    <article class="card">
      <div class="head"><h2>Fonts</h2><small>macOS system fonts, nothing is loaded from the web. On Windows and Linux each falls back to a similar font. Default: Futura for headers, Palatino for body text.</small></div>
      <div class="body">
        <div class="fonts">
          <?php foreach (['font_head' => ['Header font', '--font-head'], 'font_body' => ['Body font', '--font']] as $field => [$label, $var]): ?>
            <div>
              <label class="overline" for="<?= $field ?>"><?= e($label) ?></label>
              <select id="<?= $field ?>" name="<?= $field ?>" data-var="<?= $var ?>">
                <?php foreach (FONTS as $group => $fonts): ?>
                  <optgroup label="<?= e($group) ?>">
                    <?php foreach ($fonts as $key => [$name, $stack]): ?>
                      <option value="<?= e($key) ?>" data-stack="<?= e($stack) ?>"<?= $config[$field] === $key ? ' selected' : '' ?>><?= e($name) ?></option>
                    <?php endforeach; ?>
                  </optgroup>
                <?php endforeach; ?>
              </select>
            </div>
          <?php endforeach; ?>
        </div>
        <div class="font-sample">
          <h3>Busy — all repos</h3>
          <p>The quick brown fox jumps over the lazy dog. Items live in <code>docs/todo/</code> and move from backlog to plan, busy and done.</p>
        </div>
      </div>
    </article>
    <article class="card">
      <div class="head"><h2>Color scheme</h2><small>Light Colors is the default.</small></div>
      <div class="body">
        <div class="schemes">
          <?php foreach (SCHEMES as $key => [$name]): ?>
            <label class="scheme" data-scheme="<?= e($key) ?>">
              <input type="radio" name="scheme" value="<?= e($key) ?>"<?= $config['scheme'] === $key ? ' checked' : '' ?>>
              <span class="scheme-name"><?= e($name) ?></span>
              <span class="scheme-sample">
                <span class="chip">Button</span>
                <mark class="stage-busy">B1</mark><mark class="stage-plan">P1</mark><mark class="stage-planned">3</mark><mark class="stage-done">done</mark><mark class="stage-skipped">skip</mark>
                <small class="type type-bug">bug</small><small class="type type-feature">feature</small><small class="type type-change">change</small><small class="type type-chore">chore</small>
              </span>
            </label>
          <?php endforeach; ?>
        </div>
      </div>
    </article>
    <div class="actions">
      <button type="submit" class="btn">Save</button>
      <button type="submit" name="reset" value="1" class="btn-link">Reset to defaults</button>
    </div>
  </form>
  <script>
    // live preview before saving: fonts via the CSS variables on <html>, scheme via its data-scheme attribute
    const root = document.documentElement;
    document.querySelectorAll('.config select[data-var]').forEach(sel =>
      sel.addEventListener('change', () => root.style.setProperty(sel.dataset.var, sel.selectedOptions[0].dataset.stack)));
    document.querySelectorAll('.config input[name="scheme"]').forEach(radio =>
      radio.addEventListener('change', () => { root.dataset.scheme = radio.value; }));
  </script>
<?php elseif ($faqView): ?>
  <p class="crumbs"><a href="/">&larr; all repos</a></p>
  <article class="card faq">
    <div class="head"><h2>Frequently asked questions</h2></div>
    <div class="body md"><?= is_readable($faqFile = __DIR__ . '/faq.md') ? md_html(item_body($faqFile), true) : '<p class="notice error">faq.md not found next to index.php.</p>' ?></div>
  </article>
<?php elseif ($agentsView): ?>
  <p class="crumbs"><a href="/">&larr; all repos</a></p>
  <div class="agents-head">
    <h2>Agents</h2>
    <span class="counts">
      <?php foreach (AGENT_GROUPS as $key => $label): ?>
        <span class="count state-<?= e($key) ?>"><i class="dot"></i><?= $agentCounts[$key] ?> <?= e(strtolower($label)) ?></span>
      <?php endforeach; ?>
    </span>
    <a class="btn-link" href="/agents<?= $byRepo ? '' : '?by=repo' ?>"><?= $byRepo ? 'Group by state' : 'Group by repo' ?></a>
  </div>
  <?php if ($agentsError !== null): ?>
    <p class="notice error">Could not list sessions: <?= e($agentsError) ?></p>
  <?php elseif ($agentGroups === []): ?>
    <article class="card"><div class="body"><p class="empty">No Claude Code sessions running.</p></div></article>
  <?php else: ?>
    <div class="agents-layout<?= $peekSession !== null ? ' with-peek' : '' ?>">
      <article class="card agents-list"><div class="body">
        <?php foreach ($agentGroups as $g): ?>
          <h3 class="overline<?= isset($g['key']) ? ' state-' . e($g['key']) : '' ?>"><?= e($g['label']) ?> <small>(<?= count($g['rows']) ?>)</small></h3>
          <ul class="agents">
            <?php foreach ($g['rows'] as $row) echo render_agent_row($row['s'], $row['block'], $row['busy'], $peekSession !== null && $row['s']['sessionId'] === $peekSession['s']['sessionId'], $byParam, $row['prompt']); ?>
          </ul>
        <?php endforeach; ?>
      </div></article>
      <?php if ($peekSession !== null): ?>
        <?php $ps = $peekSession['s']; $attach = $ps['id'] !== '' ? $ps['id'] : $ps['name']; ?>
        <article class="card peek">
          <div class="head">
            <h2><i class="dot state-<?= e($ps['group']) ?> sub-<?= e($ps['sub']) ?>"></i><?= e($ps['name']) ?></h2>
            <a class="close" href="/agents<?= $byRepo ? '?by=repo' : '' ?>" aria-label="Close">&times;</a>
            <small><?= e($ps['sub'] !== '' ? $ps['sub'] : $ps['group']) ?><?= $ps['kind'] !== '' ? ' · ' . e($ps['kind']) : '' ?><?= $ps['started'] > 0 ? ' · started ' . e(ago($ps['started'])) : '' ?></small>
          </div>
          <div class="body">
            <?php if ($peek['title'] !== null): ?><h3 class="peek-title"><?= e($peek['title']) ?></h3><?php endif; ?>
            <?php if ($ps['waitingFor'] !== ''): ?><p class="waiting">Waiting for: <?= e($ps['waitingFor']) ?></p><?php endif; ?>
            <?php if ($peekSession['busy'] !== null): ?>
              <p class="peek-item"><mark class="stage-busy"><?= e($peekSession['busy']['id']) ?></mark> <a href="file://<?= e($peekSession['busy']['file']) ?>"><?= e($peekSession['busy']['title']) ?></a></p>
            <?php endif; ?>
            <h4 class="overline">Last prompt</h4>
            <?= $peek['prompt'] !== null ? '<pre class="peek-text">' . e($peek['prompt']) . '</pre>' : '<p class="empty">none found</p>' ?>
            <h4 class="overline">Last reply</h4>
            <?= $peek['reply'] !== null ? '<pre class="peek-text">' . e($peek['reply']) . '</pre>' : '<p class="empty">none found</p>' ?>
            <dl class="peek-meta">
              <dt>Folder</dt><dd><code><?= e($ps['cwd']) ?></code></dd>
              <dt>Session</dt><dd><code><?= e($ps['sessionId']) ?></code></dd>
              <?php if ($peek['file'] === null): ?><dt>Transcript</dt><dd>not found</dd><?php endif; ?>
            </dl>
            <?php if ($ps['kind'] === 'interactive'): ?>
              <p class="hint">Running in a terminal; switch to that window to continue it.</p>
            <?php else: ?>
              <p class="attach"><code id="attach-cmd">claude attach <?= e($attach) ?></code>
                <button type="button" class="btn-link" id="copy-attach">Copy</button></p>
              <script>
                // copy the attach command; the page has no other script
                document.getElementById('copy-attach').addEventListener('click', e => {
                  try { navigator.clipboard.writeText(document.getElementById('attach-cmd').textContent).then(() => { e.target.textContent = 'Copied'; }); } catch (err) {}
                });
              </script>
            <?php endif; ?>
          </div>
        </article>
      <?php endif; ?>
    </div>
  <?php endif; ?>
<?php elseif ($detail !== null): ?>
  <p class="crumbs"><a href="<?= e($showAll ? './?all=1' : './') ?>">&larr; all repos</a></p>
  <article class="card repo-detail">
    <div class="head">
      <h2><?php if ($detail['icon'] !== null): ?><img class="favicon" src="<?= e($detail['icon']) ?>" alt="" width="24" height="24"><?php endif; ?><?= e($detail['repo']['name']) ?><?php if ($detail['laravel']): ?> <img class="laravel" src="laravel.svg" alt="Laravel" title="Laravel project (artisan found)" width="18" height="18"><?php endif; ?> <span class="agent-slot" data-idx="<?= $detail['idx'] ?>"><?= render_agents($detail['agents']) ?></span></h2>
      <small><code><?= e($detail['repo']['path']) ?></code> · registered <?= e($detail['repo']['registered']) ?> · last seen <?= e($detail['repo']['last_seen']) ?></small>
      <p class="view-toggle"><?php $repoUrl = './?repo=' . $detail['idx']; $allParam = $showAll ? '&all=1' : ''; ?>
        <?php if ($tableView): ?><a href="<?= e($repoUrl . $allParam) ?>">Kanban view</a><?php else: ?><a href="<?= e($repoUrl . '&view=table' . $allParam) ?>">Table view</a><?php endif; ?></p>
    </div>
    <div class="body">
      <?php if ($tableView): ?>
        <?php foreach (['busy' => 'B', 'plan' => 'P', 'planned' => ''] + ($showAll ? ['someday' => 'S', 'done' => '', 'skipped' => ''] : []) as $stage => $prefix): ?>
          <h3 class="overline <?= e($stage) ?>"><?= e($stages[$stage]['label']) ?> <small>(<?= count($detail['data'][$stage]) ?>)</small></h3>
          <?= render_table($detail['data'][$stage], $prefix, $stage) ?>
        <?php endforeach; ?>
      <?php else: ?>
        <?= render_kanban($detail['data'], $stages, git_last_activity(dirname($detail['todo'], 2)), $repoUrl . '&view=table&all=1') ?>
      <?php endif; ?>
    </div>
  </article>
<?php else: ?>
  <?php if ($blocks === []): ?>
    <article class="card"><div class="body">
      <p>No registered repos yet. Run <code>/fodo:list</code> inside a repo that uses <code>docs/todo/</code>.</p>
    </div></article>
  <?php else: ?>
    <?php
      // agents in repos without a busy item (or outside any registered repo) get their own rows
      $busyIdx = array_unique(array_map(fn($it) => $it['block']['idx'], $busyAll));
      $agentRows = [];
      foreach ($blocks as $b) {
          if ($b['agents'] !== [] && !in_array($b['idx'], $busyIdx, true)) {
              $agentRows[] = ['block' => $b, 'agents' => $b['agents'], 'label' => $b['repo']['name']];
          }
      }
      foreach ($agentsElsewhere as $sess) {
          $agentRows[] = ['block' => null, 'agents' => [$sess], 'label' => basename($sess['cwd'])];
      }
    ?>
    <article class="card busy-all" id="busy-all">
      <div class="body">
        <h3 class="overline busy">Busy — all repos <small>(<?= count($busyAll) ?>)</small>
          <?php if ($agentCount > 0): ?><small class="agent-count"><?= $agentCount ?> agent<?= $agentCount === 1 ? '' : 's' ?> running</small><?php endif; ?></h3>
        <?php if ($busyAll === [] && $agentRows === []): ?>
          <p class="empty">nothing in progress</p>
        <?php else: ?>
          <ul class="busy-all">
            <?php foreach ($busyAll as $it): ?>
              <li<?= waiting_cls($it) !== '' ? ' class="item-waiting"' : '' ?>>
                <a class="repo" href="./?repo=<?= $it['block']['idx'] ?>"><?php if ($it['block']['icon'] !== null): ?><img class="favicon" src="<?= e($it['block']['icon']) ?>" alt="" width="16" height="16"><?php endif; ?><?= e($it['block']['repo']['name']) ?><?php if ($it['block']['laravel']): ?><img class="laravel" src="laravel.svg" alt="Laravel" title="Laravel project" width="14" height="14"><?php endif; ?></a>
                <?= render_agents($it['block']['agents']) ?>
                <mark class="stage-busy<?= waiting_cls($it) ?>"><?= e($it['id']) ?></mark>
                <a class="title" href="file://<?= e($it['file']) ?>" title="<?= e($it['title'] . ' — ' . $it['base']) ?>"><?= e(short($it['title'], 80)) ?></a><?= waiting_html($it) ?>
                <small class="type type-<?= e($it['type']) ?>"><?= e($it['type']) ?></small>
                <time datetime="<?= e(date('c', $it['activity']['ts'])) ?>" title="<?= e($it['activity']['why']) ?>"><?= e(ago($it['activity']['ts'])) ?></time>
              </li>
            <?php endforeach; ?>
            <?php foreach ($agentRows as $row): ?>
              <li class="agent-only">
                <?php if ($row['block'] !== null): ?>
                  <a class="repo" href="./?repo=<?= $row['block']['idx'] ?>"><?php if ($row['block']['icon'] !== null): ?><img class="favicon" src="<?= e($row['block']['icon']) ?>" alt="" width="16" height="16"><?php endif; ?><?= e($row['label']) ?></a>
                <?php else: ?>
                  <span class="repo" title="<?= e($row['agents'][0]['cwd']) ?>"><?= e($row['label']) ?></span>
                <?php endif; ?>
                <?= render_agents($row['agents']) ?>
                <span class="title"><?= $row['block'] !== null ? 'no busy item' : 'not a registered repo' ?></span>
              </li>
            <?php endforeach; ?>
          </ul>
        <?php endif; ?>
      </div>
    </article>
  <?php endif; ?>

  <?php if ($active !== []): ?>
    <section class="grid active">
      <?php foreach ($active as $b) echo render_card($b, $showAll); ?>
    </section>
  <?php endif; ?>
  <?php if ($active !== [] && ($idle !== [] || $empty !== [])): ?>
    <hr class="group-divider" title="repos without busy or plan items">
  <?php endif; ?>
  <?php if ($idle !== []): ?>
    <section class="grid idle">
      <?php foreach ($idle as $b) echo render_card($b, $showAll); ?>
    </section>
  <?php endif; ?>
  <?php if ($empty !== []): ?>
    <?php $emptyLabel = count($empty) . ' empty repo' . (count($empty) === 1 ? '' : 's'); ?>
    <p class="empty-toggle">
      <button type="button" class="btn-link" id="toggle-empty" aria-expanded="false" aria-controls="empty-repos"
              data-show="Show <?= e($emptyLabel) ?>" data-hide="Hide <?= e($emptyLabel) ?>">Show <?= e($emptyLabel) ?></button>
    </p>
    <section class="grid idle" id="empty-repos" title="repos with nothing in backlog, plan or busy" hidden>
      <?php foreach ($empty as $b) echo render_card($b, $showAll); ?>
    </section>
    <script>
      // show/hide the empty repos; the choice is remembered per browser
      (() => {
        const btn = document.getElementById('toggle-empty'), grid = document.getElementById('empty-repos');
        const set = open => {
          grid.hidden = !open;
          btn.setAttribute('aria-expanded', String(open));
          btn.textContent = open ? btn.dataset.hide : btn.dataset.show;
          try { localStorage.setItem('fodo.showEmpty', open ? '1' : '0'); } catch (e) {}
        };
        try { if (localStorage.getItem('fodo.showEmpty') === '1') set(true); } catch (e) {}
        btn.addEventListener('click', () => set(grid.hidden));
      })();
    </script>
  <?php endif; ?>

  <?php if ($missing !== []): ?>
    <article class="card warning"><div class="body">
      <h3 class="overline">Missing</h3>
      <p>Registered, but <code>docs/todo/</code> was not found. Run <code>/fodo:repos prune</code> to drop them.</p>
      <ul>
        <?php foreach ($missing as $m): ?>
          <li><?= e($m['name']) ?> — <code><?= e($m['path']) ?></code></li>
        <?php endforeach; ?>
      </ul>
    </div></article>
  <?php endif; ?>
<?php endif; ?>
</main>

<footer>
  fodo<?= $version !== '' ? ' v' . e($version) : '' ?> · <?= e(function_exists('posix_getpwuid') ? (posix_getpwuid(posix_geteuid())['name'] ?? get_current_user()) : get_current_user()) ?> @ <?= e(preg_replace('/\.local$/', '', php_uname('n'))) ?> · <?= count($blocks) ?> repo<?= count($blocks) === 1 ? '' : 's' ?> · generated <?= e(date('Y-m-d H:i')) ?>
</footer>
</body>
</html>
