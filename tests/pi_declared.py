"""Checks the declared Pi documents and drives the merger over them.

Usage: pi_declared.py MERGER MODELS SETTINGS SYNTHETIC OPENROUTER BUNDLED
                      RENDERER SYNTHETIC_HELPER OPENROUTER_HELPER WORKDIR
                      DEFAULT_MODEL

MODELS and SETTINGS are the declared documents home.activation hands the
merger. SYNTHETIC and OPENROUTER are the committed catalog snapshots, BUNDLED
lists the OpenRouter model IDs the installed Pi bundles (one per line, from
its own --list-models), RENDERER is home/h82/agents/pi-declarations.py, and
the helpers are the installed key helpers. DEFAULT_MODEL is the model
source's default model ID.

The expected value of each rendered model is derived here from its snapshot
row by the rules the plan states, and a handful of fixture rows run through
RENDERER pin those rules with literal values. Prints one line per failure and
exits 1 when there is any.
"""
import json
import math
import os
import stat
import subprocess
import sys

(merger, models_path, settings_path, synthetic_path, openrouter_path, bundled_path,
 renderer, synthetic_helper, openrouter_helper, workdir, default_model) = sys.argv[1:12]
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def load(path):
    with open(path) as handle:
        return json.load(handle)


def dump(path, document):
    with open(path, 'w') as handle:
        json.dump(document, handle)


SYNTHETIC = ['providers', 'synthetic']
OPENROUTER = ['providers', 'openrouter']
GLM = 'hf:zai-org/GLM-5.3'
GLM_FLASH = 'hf:zai-org/GLM-5.3-Flash'
DEEPSEEK = 'hf:deepseek-ai/DeepSeek-V4.1-Flash-1017'
KIMI = 'hf:moonshotai/Kimi-K3'
LEVELS = ['off', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max']
PER_MILLION = 1000000

models = load(models_path)
settings = load(settings_path)
synthetic_rows = load(synthetic_path)['data']
openrouter_rows = load(openrouter_path)['data']
with open(bundled_path) as handle:
    bundled = {line.strip() for line in handle if line.strip()}
check(bundled, 'the installed Pi lists no bundled OpenRouter model')


def per_million(price):
    """Pi's perMillion: rounded to six places, and a missing, unparseable, or
    negative price is 0."""
    try:
        value = float((price or '').lstrip('$'))
    except ValueError:
        return 0
    return round(value * PER_MILLION, 6) if value >= 0 else 0


def expected_map(efforts, override):
    if efforts is None or not efforts:
        return None
    mapped = {level: (level if level in efforts else None) for level in LEVELS}
    mapped['off'] = 'none' if 'none' in efforts else None
    if not override:
        for level in ('xhigh', 'max'):
            if level not in efforts:
                del mapped[level]
    return mapped


def check_model(label, got, *, name, efforts, modalities, prices, context, max_tokens, override, has_reasoning=True):
    check(got.get('name') == name, '{}: name is {!r}, expected {!r}'.format(label, got.get('name'), name))
    if override and not has_reasoning:
        check('reasoning' not in got, '{}: reasoning is {!r}, expected omitted'.format(label, got.get('reasoning')))
        check('thinkingLevelMap' not in got,
              '{}: thinkingLevelMap is {!r}, expected omitted'.format(label, got.get('thinkingLevelMap')))
    else:
        check(got.get('reasoning') is (efforts is not None), '{}: reasoning is {!r}'.format(label, got.get('reasoning')))
        check(got.get('thinkingLevelMap') == expected_map(efforts, override),
              '{}: thinkingLevelMap is {!r}, expected {!r}'.format(label, got.get('thinkingLevelMap'),
                                                                  expected_map(efforts, override)))
    check(got.get('input') == [m for m in ('text', 'image') if m in modalities],
          '{}: input is {!r} for modalities {!r}'.format(label, got.get('input'), modalities))
    cost = got.get('cost', {})
    check(sorted(cost) == sorted(prices), '{}: cost fields are {}'.format(label, sorted(cost)))
    for field, price in prices.items():
        want = per_million(price)
        check(isinstance(cost.get(field), (int, float)) and math.isclose(cost.get(field), want, rel_tol=1e-9, abs_tol=1e-9),
              '{}: cost.{} is {!r}, expected {}'.format(label, field, cost.get(field), want))
    for field, value in (('contextWindow', context), ('maxTokens', max_tokens)):
        if isinstance(value, int) and value > 0:
            check(got.get(field) == value, '{}: {} is {!r}, expected {}'.format(label, field, got.get(field), value))
        else:
            check(field not in got, '{}: {} is rendered from {!r}'.format(label, field, value))


def check_synthetic(row, got):
    reasoning = row.get('reasoning_parameters')
    pricing = row['pricing']
    check_model(
        'synthetic ' + row['id'], got,
        name=row['display_name'],
        efforts=None if reasoning is None else reasoning.get('efforts') or [],
        modalities=row['input_modalities'],
        prices={'input': pricing.get('prompt'), 'output': pricing.get('completion'),
                'cacheRead': pricing.get('input_cache_reads'), 'cacheWrite': pricing.get('input_cache_writes')},
        context=row['context_length'], max_tokens=row['max_output_length'], override=False)


def check_openrouter(row, got, override):
    has_reasoning = 'reasoning' in row
    reasoning = row.get('reasoning')
    pricing = row['pricing']
    top = row.get('top_provider') or {}
    context = top.get('context_length')
    check_model(
        'openrouter ' + row['id'], got,
        name=row['name'],
        efforts=None if reasoning is None else reasoning.get('supported_efforts') or [],
        modalities=row['architecture']['input_modalities'],
        prices={'input': pricing.get('prompt'), 'output': pricing.get('completion'),
                'cacheRead': pricing.get('input_cache_read'), 'cacheWrite': pricing.get('input_cache_write')},
        context=context if isinstance(context, int) and context > 0 else row.get('context_length'),
        max_tokens=top.get('max_completion_tokens'), override=override, has_reasoning=has_reasoning)


def owned(document, path):
    matches = [entry for entry in document.get('ownEntries', []) if entry.get('path') == path]
    check(len(matches) == 1, '{} owned entry sets declared at {}'.format(len(matches), path))
    return matches[0] if matches else {}


# --- models.json declaration over the real snapshots -------------------------

check(set(models) == {'setPaths', 'ownEntries'},
      'the models declaration carries fields {}, expected setPaths and ownEntries'.format(sorted(models)))
scalars = {tuple(entry['path']): entry['value'] for entry in models.get('setPaths', [])}
check(scalars == {
    tuple(SYNTHETIC + ['name']): 'Synthetic',
    tuple(SYNTHETIC + ['baseUrl']): 'https://api.synthetic.new/openai/v1',
    tuple(SYNTHETIC + ['api']): 'openai-completions',
    tuple(SYNTHETIC + ['apiKey']): '!' + synthetic_helper,
    tuple(OPENROUTER + ['apiKey']): '!' + openrouter_helper,
}, 'the provider scalars are {}'.format(scalars))
check(len(models.get('ownEntries', [])) == 3, 'the models declaration owns {} entry sets, expected 3'.format(
    len(models.get('ownEntries', []))))

# The declaration names no key and no key file: only the two helpers do.
text = open(models_path).read()
check(text.count('apiKey') == 2, 'apiKey appears {} times in the models declaration'.format(text.count('apiKey')))
for forbidden in ('synthetic_api_key', 'openrouter_api_key', 'exa_api_key', 'authHeader', 'headers', 'sk-'):
    check(forbidden not in text, 'the models declaration holds {!r}'.format(forbidden))

synthetic_set = owned(models, SYNTHETIC + ['models'])
check(synthetic_set.get('key') == 'id', 'the synthetic models are not keyed by id')
check(synthetic_set.get('preLedgerIds') == sorted([GLM, GLM_FLASH, DEEPSEEK, KIMI]),
      'the synthetic preLedgerIds are {}'.format(synthetic_set.get('preLedgerIds')))
synthetic_declared = synthetic_set.get('entries', [])
synthetic_by_id = {entry.get('id'): entry for entry in synthetic_declared}
check(len(synthetic_by_id) == len(synthetic_declared), 'a synthetic model is declared twice')
check(sorted(synthetic_by_id) == sorted(row['id'] for row in synthetic_rows),
      'the declared synthetic models are not the snapshot rows: {}'.format(sorted(synthetic_by_id)))
for row in synthetic_rows:
    if row['id'] in synthetic_by_id:
        check_synthetic(row, synthetic_by_id[row['id']])

openrouter_models = owned(models, OPENROUTER + ['models'])
check(openrouter_models.get('key') == 'id' and openrouter_models.get('preLedgerIds') == [],
      'the openrouter models set is not keyed by id with no preLedgerIds')
overrides = owned(models, OPENROUTER + ['modelOverrides'])
check('key' not in overrides and overrides.get('preLedgerIds') == [],
      'the openrouter modelOverrides set is not an object with no preLedgerIds')
models_by_id = {entry.get('id'): entry for entry in openrouter_models.get('entries', [])}
override_by_id = overrides.get('entries', {})
check(len(models_by_id) == len(openrouter_models.get('entries', [])), 'an openrouter model is declared twice')
snapshot_ids = {row['id'] for row in openrouter_rows}
check(set(override_by_id) == snapshot_ids & bundled,
      'openrouter modelOverrides are not the snapshot rows Pi bundles: {} extra, {} missing'.format(
          len(set(override_by_id) - (snapshot_ids & bundled)), len((snapshot_ids & bundled) - set(override_by_id))))
check(set(models_by_id) == snapshot_ids - bundled,
      'openrouter models are not the snapshot rows Pi does not bundle: {} extra, {} missing'.format(
          len(set(models_by_id) - (snapshot_ids - bundled)), len((snapshot_ids - bundled) - set(models_by_id))))
check(override_by_id and models_by_id, 'the real snapshot renders no override or no model, so the split is untested')
for row in openrouter_rows:
    if row['id'] in override_by_id:
        check_openrouter(row, override_by_id[row['id']], override=True)
        check('id' not in override_by_id[row['id']], 'override {} carries an id field'.format(row['id']))
    elif row['id'] in models_by_id:
        check_openrouter(row, models_by_id[row['id']], override=False)

fixture_dir = os.path.join(workdir, 'fixture')
os.makedirs(fixture_dir, exist_ok=True)
dump(os.path.join(fixture_dir, 'synthetic.json'), {'data': [
    {'id': 'hf:fixture/Plain', 'display_name': 'Plain', 'input_modalities': ['text', 'image'],
     'context_length': 131072, 'max_output_length': 8192,
     'pricing': {'prompt': '$0.0000014', 'completion': '$0.0000044', 'input_cache_reads': '$0.00000014',
                 'input_cache_writes': '0'}},
]})
dump(os.path.join(fixture_dir, 'openrouter.json'), {'data': [
    {'id': 'fixture/three-efforts', 'name': 'Three efforts',
     'architecture': {'input_modalities': ['text', 'file', 'audio'], 'output_modalities': ['text']},
     'context_length': 64000, 'top_provider': {'context_length': None, 'max_completion_tokens': None},
     'pricing': {'prompt': '-1', 'completion': '0.000002'},
     'reasoning': {'supported_efforts': ['high', 'low', 'none']}},
    {'id': 'fixture/bundled', 'name': 'Bundled',
     'architecture': {'input_modalities': ['image', 'text'], 'output_modalities': ['text']},
     'context_length': 64000, 'top_provider': {'context_length': 32000, 'max_completion_tokens': 4096},
     'pricing': {'prompt': '0.000001', 'completion': '0.000002', 'input_cache_read': '0.0000001',
                 'input_cache_write': '0.00000125'},
     'reasoning': {'supported_efforts': ['low', 'high', 'max']}},
    {'id': 'fixture/bundled-no-reasoning', 'name': 'Bundled without reasoning key',
     'architecture': {'input_modalities': ['text'], 'output_modalities': ['text']},
     'context_length': 200000, 'top_provider': {'context_length': 200000, 'max_completion_tokens': None},
     'pricing': {'prompt': '-1', 'completion': '-1'}},
    {'id': 'fixture/bundled-null-reasoning', 'name': 'Bundled with null reasoning',
     'architecture': {'input_modalities': ['text'], 'output_modalities': ['text']},
     'context_length': 128000, 'top_provider': {'context_length': 128000, 'max_completion_tokens': 4096},
     'pricing': {'prompt': '0.000001', 'completion': '0.000002'},
     'reasoning': None},
    {'id': 'fixture/no-efforts', 'name': 'No efforts',
     'architecture': {'input_modalities': ['text'], 'output_modalities': ['text']},
     'context_length': 0, 'top_provider': {'context_length': 0, 'max_completion_tokens': 0},
     'pricing': {'prompt': '0', 'completion': '0'},
     'reasoning': {'mandatory': True}},
]})
with open(os.path.join(fixture_dir, 'bundled'), 'w') as handle:
    handle.write('fixture/bundled\nfixture/bundled-no-reasoning\nfixture/bundled-null-reasoning\nfixture/not-in-snapshot\n')
with open(os.path.join(fixture_dir, 'pre-ledger'), 'w') as handle:
    handle.write('hf:fixture/Legacy\n')
fixture_out = os.path.join(fixture_dir, 'declared.json')
rendered = subprocess.run(
    [sys.executable, '-I', renderer, os.path.join(fixture_dir, 'synthetic.json'),
     os.path.join(fixture_dir, 'openrouter.json'), os.path.join(fixture_dir, 'bundled'),
     os.path.join(fixture_dir, 'pre-ledger'),
     '/helpers/synthetic', '/helpers/openrouter', fixture_out],
    capture_output=True, text=True,
)
check(rendered.returncode == 0, 'the renderer failed on the fixture rows: {}'.format(rendered.stderr.strip()))
fixture = load(fixture_out) if rendered.returncode == 0 else {}
fixture_sets = {tuple(entry['path']): entry['entries'] for entry in fixture.get('ownEntries', [])}
check(owned(fixture, SYNTHETIC + ['models']).get('preLedgerIds') == ['hf:fixture/Legacy'],
      'fixture synthetic preLedgerIds are {}'.format(owned(fixture, SYNTHETIC + ['models']).get('preLedgerIds')))
expected_sets = {
    ('providers', 'synthetic', 'models'): [{
        'id': 'hf:fixture/Plain', 'name': 'Plain', 'reasoning': False, 'input': ['text', 'image'],
        'cost': {'input': 1.4, 'output': 4.4, 'cacheRead': 0.14, 'cacheWrite': 0},
        'contextWindow': 131072, 'maxTokens': 8192,
    }],
    ('providers', 'openrouter', 'models'): [
        {
            'id': 'fixture/three-efforts', 'name': 'Three efforts', 'reasoning': True,
            'thinkingLevelMap': {'off': 'none', 'minimal': None, 'low': 'low', 'medium': None, 'high': 'high'},
            'input': ['text'],
            'cost': {'input': 0, 'output': 2, 'cacheRead': 0, 'cacheWrite': 0},
            'contextWindow': 64000,
        },
        {
            'id': 'fixture/no-efforts', 'name': 'No efforts', 'reasoning': True, 'input': ['text'],
            'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
        },
    ],
    ('providers', 'openrouter', 'modelOverrides'): {
        'fixture/bundled': {
            'name': 'Bundled', 'reasoning': True,
            'thinkingLevelMap': {'off': None, 'minimal': None, 'low': 'low', 'medium': None, 'high': 'high',
                                 'xhigh': None, 'max': 'max'},
            'input': ['text', 'image'],
            'cost': {'input': 1, 'output': 2, 'cacheRead': 0.1, 'cacheWrite': 1.25},
            'contextWindow': 32000, 'maxTokens': 4096,
        },
        'fixture/bundled-no-reasoning': {
            'name': 'Bundled without reasoning key',
            'input': ['text'],
            'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
            'contextWindow': 200000,
        },
        'fixture/bundled-null-reasoning': {
            'name': 'Bundled with null reasoning', 'reasoning': False,
            'input': ['text'],
            'cost': {'input': 1, 'output': 2, 'cacheRead': 0, 'cacheWrite': 0},
            'contextWindow': 128000, 'maxTokens': 4096,
        },
    },
}


def close(got, want):
    """Equality with floats compared to a relative tolerance."""
    if isinstance(want, dict):
        return isinstance(got, dict) and sorted(got) == sorted(want) and all(close(got[k], want[k]) for k in want)
    if isinstance(want, list):
        return isinstance(got, list) and len(got) == len(want) and all(close(g, w) for g, w in zip(got, want))
    if isinstance(want, (int, float)) and not isinstance(want, bool):
        return isinstance(got, (int, float)) and not isinstance(got, bool) and math.isclose(got, want, abs_tol=1e-9)
    return got == want


for path, want in expected_sets.items():
    check(close(fixture_sets.get(path), want),
          'fixture rows at {} render {}, expected {}'.format(list(path), fixture_sets.get(path), want))

# --- settings.json declaration -----------------------------------------------

MIGRATION = 'pi-startup-levels-2026-10'
HISTORICAL = [(GLM, ['max']), (GLM_FLASH, ['high']), (DEEPSEEK, ['low', 'high']), (KIMI, ['max'])]
check(set(settings) == {'set', 'removePaths'},
      'the settings declaration carries fields {}, expected set and removePaths'.format(sorted(settings)))
check(settings.get('set') == {'defaultProvider': 'synthetic', 'defaultModel': default_model,
                              'defaultProjectTrust': 'never'},
      'settings set is {}'.format(settings.get('set')))
removals = {(tuple(entry['path']), entry['key']): entry for entry in settings.get('removePaths', [])}
check(len(removals) == len(settings.get('removePaths', [])) == len(HISTORICAL),
      'the settings declaration removes {}'.format(settings.get('removePaths')))
for model_id, values in HISTORICAL:
    entry = removals.get((('modelThinkingLevels',), 'synthetic/' + model_id), {})
    matched = entry.get('values', [entry['value']] if 'value' in entry else None)
    check(sorted(matched or []) == sorted(values) and entry.get('migration') == MIGRATION,
          'the startup level of {} is removed by {}, expected values {} under migration {}'.format(
              model_id, entry, values, MIGRATION))

# --- merging ----------------------------------------------------------------


def merge(target, declared_path, label, ledger):
    result = subprocess.run(
        [merger, '--label', label, '--settings', target, '--declared', declared_path, '--ledger', ledger],
        env={}, capture_output=True, text=True,
    )
    check(result.returncode == 0, 'the {} merger refused {}: {}'.format(label, target, result.stderr.strip()))


def mode(path):
    return stat.S_IMODE(os.stat(path).st_mode)


def entries_at(document, path):
    node = document
    for key in path:
        node = node.get(key, {}) if isinstance(node, dict) else {}
    return node


# An OpenRouter model and override the merger wrote on an earlier apply,
# which the snapshot no longer has, leave models.json; a model and a provider
# the user added by hand stay.
hand_added = {'id': 'hf:example/Hand-Added', 'name': 'Hand added', 'contextWindow': 1000}
hand_openrouter = {'id': 'example/hand-added', 'name': 'Hand added'}
other_provider = {'baseUrl': 'http://localhost:11434/v1', 'api': 'openai-completions', 'apiKey': 'ollama',
                  'models': [{'id': 'llama3'}]}
GONE_MODEL, GONE_OVERRIDE = 'gone/model', 'gone/override'
earlier = json.loads(json.dumps(models))
for entry in earlier.get('ownEntries', []):
    if entry['path'] == OPENROUTER + ['models']:
        entry['entries'] = entry['entries'] + [{'id': GONE_MODEL, 'name': 'Gone', 'reasoning': False,
                                                'input': ['text'], 'cost': {}}]
    elif entry['path'] == OPENROUTER + ['modelOverrides']:
        entry['entries'] = dict(entry['entries'], **{GONE_OVERRIDE: {'name': 'Gone override'}})
earlier_path = os.path.join(workdir, 'earlier-models.json')
dump(earlier_path, earlier)

seeded_models = os.path.join(workdir, 'models.json')
models_ledger = os.path.join(workdir, 'models-ledger.json')
dump(seeded_models, {'providers': {
    'ollama': other_provider,
    'synthetic': {'compat': {'supportsStore': False},
                  'models': [hand_added, {'id': GLM, 'name': 'user edit', 'maxTokens': 1}]},
    'openrouter': {'models': [hand_openrouter]},
}})
os.chmod(seeded_models, 0o644)
merge(seeded_models, earlier_path, 'Pi models', models_ledger)
before = load(seeded_models)
check(any(entry.get('id') == GONE_MODEL for entry in entries_at(before, OPENROUTER + ['models'])),
      'the earlier declaration did not write its extra model, so the prune below proves nothing')
merge(seeded_models, models_path, 'Pi models', models_ledger)
first = load(seeded_models)
merge(seeded_models, models_path, 'Pi models', models_ledger)
second = load(seeded_models)
check(first == second, 'merging the models declaration twice changed the file')
check(mode(seeded_models) == 0o600, 'merged models.json is mode {:o}'.format(mode(seeded_models)))
check(first['providers'].get('ollama') == other_provider, 'the second provider did not survive the merge')
merged_openrouter = [entry.get('id') for entry in entries_at(first, OPENROUTER + ['models'])]
check(GONE_MODEL not in merged_openrouter, 'an openrouter model the snapshot dropped stayed in models.json')
check(GONE_OVERRIDE not in entries_at(first, OPENROUTER + ['modelOverrides']),
      'an openrouter override the snapshot dropped stayed in models.json')
check(sorted(merged_openrouter) == sorted([hand_openrouter['id']] + list(models_by_id)),
      'the merged openrouter models are not the declared ones plus the hand-added one')
check(entries_at(first, OPENROUTER + ['modelOverrides']) == override_by_id,
      'the merged openrouter overrides are not the declared ones')
synthetic = first['providers'].get('synthetic', {})
check(synthetic.get('compat') == {'supportsStore': False}, 'a user key beside the declared provider scalars was lost')
synthetic_merged = {entry['id']: entry for entry in synthetic.get('models', [])}
check(len(synthetic.get('models', [])) == len(synthetic_merged), 'the merge left a duplicate synthetic model')
check(synthetic_merged.get(hand_added['id']) == hand_added, 'the hand-added synthetic model did not survive')
check(sorted(synthetic_merged) == sorted([hand_added['id']] + list(synthetic_by_id)),
      'merged synthetic ids are {}'.format(sorted(synthetic_merged)))
check(synthetic_merged.get(GLM) == synthetic_by_id.get(GLM), 'the stale GLM entry was not replaced')

created_models = os.path.join(workdir, 'created-models.json')
merge(created_models, models_path, 'Pi models', os.path.join(workdir, 'created-ledger.json'))
created = load(created_models) if os.path.exists(created_models) else {}
check(sorted(entry['id'] for entry in entries_at(created, SYNTHETIC + ['models'])) == sorted(synthetic_by_id),
      'merging into a missing models.json did not create every synthetic model')
check(os.path.exists(created_models) and mode(created_models) == 0o600, 'a created models.json is not mode 0600')

# The startup levels the migration retires leave settings.json, while a
# level the user chose stays, both on another model and on one of the four
# when it no longer holds the value this repository wrote.
QWEN = 'synthetic/hf:Qwen/Qwen3.8-27B'
seeded_settings = os.path.join(workdir, 'settings.json')
settings_ledger = os.path.join(workdir, 'settings-ledger.json')
dump(seeded_settings, {
    'theme': 'dark',
    'defaultProjectTrust': 'always',
    'modelThinkingLevels': {
        'synthetic/' + GLM: 'max',
        'synthetic/' + GLM_FLASH: 'high',
        'synthetic/' + DEEPSEEK: 'high',
        'synthetic/' + KIMI: 'max',
        QWEN: 'low',
    },
})
os.chmod(seeded_settings, 0o644)
merge(seeded_settings, settings_path, 'Pi settings', settings_ledger)
merged_settings = load(seeded_settings)
check(merged_settings == {
    'theme': 'dark',
    'defaultProvider': 'synthetic',
    'defaultModel': default_model,
    'defaultProjectTrust': 'never',
    'modelThinkingLevels': {QWEN: 'low'},
}, 'merged settings.json is {}'.format(merged_settings))
check(mode(seeded_settings) == 0o600, 'merged settings.json is mode {:o}'.format(mode(seeded_settings)))

# The cleanup runs once: a level the user saves afterwards survives the next
# apply even when it equals the one removed.
merged_settings['modelThinkingLevels']['synthetic/' + GLM] = 'max'
dump(seeded_settings, merged_settings)
merge(seeded_settings, settings_path, 'Pi settings', settings_ledger)
check(load(seeded_settings).get('modelThinkingLevels') == {QWEN: 'low', 'synthetic/' + GLM: 'max'},
      'a level saved after the cleanup did not survive the next apply: {}'.format(
          load(seeded_settings).get('modelThinkingLevels')))

user_changed = os.path.join(workdir, 'user-changed-settings.json')
dump(user_changed, {'modelThinkingLevels': {'synthetic/' + GLM: 'low', 'synthetic/' + DEEPSEEK: 'max'}})
merge(user_changed, settings_path, 'Pi settings', os.path.join(workdir, 'user-changed-ledger.json'))
check(load(user_changed).get('modelThinkingLevels') == {'synthetic/' + GLM: 'low', 'synthetic/' + DEEPSEEK: 'max'},
      'a level the user changed from the written one was removed: {}'.format(
          load(user_changed).get('modelThinkingLevels')))

for message in failures:
    print(message)
sys.exit(1 if failures else 0)
