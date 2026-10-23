"""Writes the agent-settings declaration for Pi's models.json.

Usage: pi-declarations.py SYNTHETIC_SNAPSHOT OPENROUTER_SNAPSHOT BUNDLED_IDS
                          PRE_LEDGER_IDS SYNTHETIC_KEY_HELPER
                          OPENROUTER_KEY_HELPER OUT

BUNDLED_IDS holds one OpenRouter model ID per line: the chat models the pinned
Pi bundles. PRE_LEDGER_IDS holds the Synthetic model IDs earlier generations
wrote before the ledger existed, one per line. An OpenRouter row Pi bundles
becomes a modelOverrides entry, which keeps the bundled model's api, baseUrl,
and compat; any other row becomes a models entry. Every Synthetic row becomes a
models entry. The merger owns each set through its ledger, so a row a newer
snapshot drops leaves models.json on the next apply.

Pi rejects the whole models.json when one field is invalid, so a field is
written only when the snapshot gives it a valid value.
"""
import decimal
import json
import sys

LEVELS = ('minimal', 'low', 'medium', 'high')
EXTRA_LEVELS = ('xhigh', 'max')

PER_MILLION = 1000000


def per_million(price):
    """USD per token, as a string, to USD per million tokens.

    Mirrors Pi's own perMillion: a missing, unparseable, or negative price
    (OpenRouter writes "-1") is 0, and the result is rounded to six places.
    """
    try:
        per_token = decimal.Decimal((price or '').lstrip('$'))
    except decimal.InvalidOperation:
        return 0
    if not per_token.is_finite() or per_token < 0:
        return 0
    return round(float(per_token * PER_MILLION), 6)


def positive(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def level_map(efforts, override):
    """Pi's thinking levels mapped to the efforts the catalog lists.

    `off` sends `none`. In a models entry an unlisted level up to `high` is
    null and an unlisted `xhigh` or `max` is left out, which Pi also reads as
    unsupported. A modelOverrides entry is merged over the bundled map, so
    there every level is present and null when unlisted.
    """
    mapped = {'off': 'none' if 'none' in efforts else None}
    for level in LEVELS:
        mapped[level] = level if level in efforts else None
    for level in EXTRA_LEVELS:
        if level in efforts or override:
            mapped[level] = level if level in efforts else None
    return mapped


def model(name, efforts, modalities, prices, context, max_tokens, *, override, has_reasoning=True):
    """efforts is None for a model without reasoning and [] for one that
    reasons with no effort list. On a bundled override whose snapshot row has
    no reasoning key, reasoning is omitted so Pi's bundled value stands."""
    entry = {'name': name}
    if not (override and not has_reasoning):
        entry['reasoning'] = efforts is not None
        if efforts:
            entry['thinkingLevelMap'] = level_map(efforts, override)
    entry['input'] = [modality for modality in ('text', 'image') if modality in modalities]
    entry['cost'] = {field: per_million(price) for field, price in prices.items()}
    if positive(context):
        entry['contextWindow'] = context
    if positive(max_tokens):
        entry['maxTokens'] = max_tokens
    return entry


def synthetic_entry(row):
    reasoning = row.get('reasoning_parameters')
    pricing = row.get('pricing') or {}
    entry = model(
        name=row['display_name'],
        efforts=None if reasoning is None else list((reasoning or {}).get('efforts') or []),
        modalities=row.get('input_modalities') or [],
        prices={
            'input': pricing.get('prompt'),
            'output': pricing.get('completion'),
            'cacheRead': pricing.get('input_cache_reads'),
            'cacheWrite': pricing.get('input_cache_writes'),
        },
        context=row.get('context_length'),
        max_tokens=row.get('max_output_length'),
        override=False,
    )
    return dict({'id': row['id']}, **entry)


def openrouter_entry(row, override):
    has_reasoning = 'reasoning' in row
    reasoning = row.get('reasoning')
    pricing = row.get('pricing') or {}
    top = row.get('top_provider') or {}
    context = top.get('context_length')
    return model(
        name=row['name'],
        efforts=None if reasoning is None else list((reasoning or {}).get('supported_efforts') or []),
        modalities=(row.get('architecture') or {}).get('input_modalities') or [],
        prices={
            'input': pricing.get('prompt'),
            'output': pricing.get('completion'),
            'cacheRead': pricing.get('input_cache_read'),
            'cacheWrite': pricing.get('input_cache_write'),
        },
        context=context if positive(context) else row.get('context_length'),
        max_tokens=top.get('max_completion_tokens'),
        override=override,
        has_reasoning=has_reasoning,
    )


def main(synthetic_path, openrouter_path, bundled_path, pre_ledger_path, synthetic_helper, openrouter_helper, out):
    with open(synthetic_path) as handle:
        synthetic = json.load(handle)['data']
    with open(openrouter_path) as handle:
        openrouter = json.load(handle)['data']
    with open(bundled_path) as handle:
        bundled = {line.strip() for line in handle if line.strip()}
    with open(pre_ledger_path) as handle:
        pre_ledger_ids = [line.strip() for line in handle if line.strip()]

    overrides = {}
    models = []
    for row in openrouter:
        if row['id'] in bundled:
            overrides[row['id']] = openrouter_entry(row, override=True)
        else:
            models.append(dict({'id': row['id']}, **openrouter_entry(row, override=False)))

    synthetic_at = ['providers', 'synthetic']
    openrouter_at = ['providers', 'openrouter']
    # Each apiKey is a `!` command: Pi runs the packaged helper for every
    # request, so no key reaches models.json. OpenRouter is Pi's built-in
    # provider, so it keeps its own api and baseUrl.
    provider = {
        'name': 'Synthetic',
        'baseUrl': 'https://api.synthetic.new/openai/v1',
        'api': 'openai-completions',
        'apiKey': '!' + synthetic_helper,
    }
    declaration = {
        'setPaths': [{'path': synthetic_at + [leaf], 'value': value} for leaf, value in provider.items()]
        + [{'path': openrouter_at + ['apiKey'], 'value': '!' + openrouter_helper}],
        'ownEntries': [
            {
                'path': synthetic_at + ['models'],
                'key': 'id',
                'entries': [synthetic_entry(row) for row in synthetic],
                'preLedgerIds': pre_ledger_ids,
            },
            {'path': openrouter_at + ['models'], 'key': 'id', 'entries': models, 'preLedgerIds': []},
            {'path': openrouter_at + ['modelOverrides'], 'entries': overrides, 'preLedgerIds': []},
        ],
    }
    with open(out, 'w') as handle:
        json.dump(declaration, handle, indent=1, sort_keys=True)


if __name__ == '__main__':
    main(*sys.argv[1:])
