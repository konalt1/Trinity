<?php

declare(strict_types=1);

final class KeyValues
{
    /**
     * @return array<string, mixed>
     */
    public static function parse(string $raw): array
    {
        $tokens = self::tokenize($raw);
        $i = 0;
        $n = count($tokens);
        $root = [];
        while ($i < $n) {
            $pair = self::readPair($tokens, $i, $n);
            if ($pair === null) {
                break;
            }
            [$key, $value, $i] = $pair;
            $root[$key] = $value;
        }

        return $root;
    }

    /**
     * @param list<string> $tokens
     * @return array{0: string, 1: mixed, 2: int}|null
     */
    private static function readPair(array $tokens, int $i, int $n): ?array
    {
        if ($i >= $n || $tokens[$i] === '}') {
            return null;
        }

        $key = $tokens[$i];
        $i++;
        if ($i >= $n) {
            return [$key, '', $i];
        }

        if ($tokens[$i] === '{') {
            $i++;
            $object = [];
            while ($i < $n && $tokens[$i] !== '}') {
                $child = self::readPair($tokens, $i, $n);
                if ($child === null) {
                    break;
                }
                [$childKey, $childValue, $i] = $child;
                $object[$childKey] = $childValue;
            }
            if ($i < $n && $tokens[$i] === '}') {
                $i++;
            }

            return [$key, $object, $i];
        }

        $value = $tokens[$i];
        $i++;

        return [$key, $value, $i];
    }

    /** @return list<string> */
    private static function tokenize(string $raw): array
    {
        $tokens = [];
        $n = strlen($raw);
        $i = 0;
        while ($i < $n) {
            $ch = $raw[$i];
            if ($ch === " " || $ch === "\t" || $ch === "\n" || $ch === "\r") {
                $i++;
                continue;
            }
            if ($ch === '/' && $i + 1 < $n && $raw[$i + 1] === '/') {
                $nl = strpos($raw, "\n", $i);
                $i = $nl === false ? $n : $nl + 1;
                continue;
            }
            if ($ch === '#') {
                $nl = strpos($raw, "\n", $i);
                $i = $nl === false ? $n : $nl + 1;
                continue;
            }
            if ($ch === '{' || $ch === '}') {
                $tokens[] = $ch;
                $i++;
                continue;
            }
            if ($ch === '"') {
                $i++;
                $buf = '';
                while ($i < $n) {
                    $cur = $raw[$i];
                    if ($cur === '\\' && $i + 1 < $n) {
                        $next = $raw[$i + 1];
                        $buf .= match ($next) {
                            'n' => "\n",
                            't' => "\t",
                            'r' => "\r",
                            '"' => '"',
                            '\\' => '\\',
                            default => $next,
                        };
                        $i += 2;
                        continue;
                    }
                    if ($cur === '"') {
                        $i++;
                        break;
                    }
                    $buf .= $cur;
                    $i++;
                }
                $tokens[] = $buf;
                continue;
            }

            $start = $i;
            while ($i < $n) {
                $cur = $raw[$i];
                if ($cur === " " || $cur === "\t" || $cur === "\n" || $cur === "\r" || $cur === '{' || $cur === '}' || $cur === '"') {
                    break;
                }
                $i++;
            }
            if ($i > $start) {
                $tokens[] = substr($raw, $start, $i - $start);
            } else {
                $i++;
            }
        }

        return $tokens;
    }

    public static function matchingBrace(string $raw, int $open): int
    {
        $n = strlen($raw);
        $depth = 0;
        $i = $open;
        while ($i < $n) {
            $ch = $raw[$i];
            if ($ch === '"') {
                $i++;
                while ($i < $n) {
                    if ($raw[$i] === '\\') {
                        $i += 2;
                        continue;
                    }
                    if ($raw[$i] === '"') {
                        $i++;
                        break;
                    }
                    $i++;
                }
                continue;
            }
            if ($ch === '/' && $i + 1 < $n && $raw[$i + 1] === '/') {
                $nl = strpos($raw, "\n", $i);
                $i = $nl === false ? $n : $nl + 1;
                continue;
            }
            if ($ch === '{') {
                $depth++;
            } elseif ($ch === '}') {
                $depth--;
                if ($depth === 0) {
                    return $i;
                }
            }
            $i++;
        }

        return -1;
    }
}
