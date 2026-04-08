# Regex Pattern Tables

## Validation Regex (matches valid names)

| Rule description | validation_regex |
|-----------------|-----------------|
| Lowercase alphanumeric only | `"\"^[a-z0-9]{MIN,MAX}$\""` |
| Alphanumeric only (mixed case) | `"\"^[a-zA-Z0-9]{MIN,MAX}$\""` |
| Alphanumeric + hyphens, start letter, end alphanumeric | `"\"^[a-zA-Z][a-zA-Z0-9-]{MIN-2,MAX-2}[a-zA-Z0-9]$\""` |
| Alphanumeric + hyphens + underscores | `"\"^[a-zA-Z0-9][a-zA-Z0-9_-]{MIN-2,MAX-2}[a-zA-Z0-9]$\""` |
| Alphanumeric + hyphens + underscores + periods | `"\"^[a-zA-Z0-9][a-zA-Z0-9_.-]{MIN-2,MAX-2}[a-zA-Z0-9_]$\""` |

Replace `MIN`/`MAX` with actual length values. Adjust inner group length: `{MIN-2,MAX-2}` accounts for required first/last characters.

## Cleaning Regex (matches characters to REMOVE)

| Allowed characters | cleaning regex |
|-------------------|---------------|
| Lowercase alphanumeric | `"\"[^0-9a-z]\""` |
| Alphanumeric (mixed case) | `"\"[^0-9A-Za-z]\""` |
| Alphanumeric + hyphens | `"\"[^0-9A-Za-z-]\""` |
| Alphanumeric + hyphens + underscores | `"\"[^0-9A-Za-z_-]\""` |
| Alphanumeric + hyphens + underscores + periods | `"\"[^0-9A-Za-z_.-]\""` |

## Project convention

Both `validation_regex` and `regex` values MUST be wrapped in escaped double quotes: `"\"pattern\""`. This is a project-wide convention in `resourceDefinition.json`.
