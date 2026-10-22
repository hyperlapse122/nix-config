"""Checks the declared Pi documents and drives the merger over them.

Usage: pi_declared.py MERGER MODELS SETTINGS SNAPSHOT HELPER WORKDIR IDS

MODELS and SETTINGS are the declared documents home.activation hands the
merger, SNAPSHOT is home/h82/agents/synthetic-catalog.json, and HELPER is the
installed pi-synthetic-key. IDS is a JSON object naming the model source's
glm, glmFlash, kimi, and deepseek IDs. Every expected value is written here, apart from
the model IDs, which come from the model source, so the module's own rendering
is never what the check compares against. Prints one line per failure and
exits 1 when there is any.
"""
import json
import math
import os
import stat
import subprocess
import sys

merger, models_path, settings_path, snapshot_path, helper, workdir = sys.argv[1:7]
ids = json.loads(sys.argv[7])

failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def load(path):
    with open(path) as handle:
        return json.load(handle)


GLM, GLM_FLASH, KIMI, DEEPSEEK = ids['glm'], ids['glmFlash'], ids['kimi'], ids['deepseek']

# What each model's catalog entry lists, and the map Pi must send for it: a
# listed effort maps to itself, `off` maps to `none` when listed, and every
# other level is null; `xhigh` and `max` appear only when listed.
THREE_EFFORTS = {'off': None, 'minimal': None, 'low': 'low', 'medium': None, 'high': 'high', 'max': 'max'}
LEVEL_MAPS = {
    GLM: THREE_EFFORTS,
    GLM_FLASH: THREE_EFFORTS,
    KIMI: THREE_EFFORTS,
    DEEPSEEK: {
        'off': 'none', 'minimal': None, 'low': 'low', 'medium': None, 'high': 'high', 'xhigh': 'xhigh', 'max': 'max',
    },
}
# The effort each model starts at: its default, except the text-generation
# model, which starts at the text-generation role's effort.
STARTUP = {GLM: 'max', GLM_FLASH: 'high', KIMI: 'max', DEEPSEEK: 'low'}

models = load(models_path)
settings = load(settings_path)
snapshot = {entry['id']: entry for entry in load(snapshot_path)['data']}

# --- models.json declaration ------------------------------------------------

scalars = {
    entry['path'][-1]: entry['value']
    for entry in models.get('setPaths', [])
    if entry['path'][:2] == ['providers', 'synthetic'] and len(entry['path']) == 3
}
check(scalars.get('api') == 'openai-completions', 'provider api is not openai-completions: {!r}'.format(scalars.get('api')))
check(scalars.get('baseUrl') == 'https://api.synthetic.new/openai/v1', 'provider baseUrl is {!r}'.format(scalars.get('baseUrl')))
check(scalars.get('apiKey') == '!' + helper, 'provider apiKey is {!r}, not the ! command naming {}'.format(scalars.get('apiKey'), helper))
check(
    sorted(scalars) == ['api', 'apiKey', 'baseUrl', 'name'],
    'provider scalars are {}, expected api, apiKey, baseUrl, name only'.format(sorted(scalars)),
)
check(
    len(models.get('setPaths', [])) == len(scalars) and set(models) == {'setPaths', 'upsertPaths'},
    'the models declaration carries something besides the provider scalars and model upserts',
)

# Nothing in the document may hold a key: the only credential-shaped field is
# the apiKey command, and the key file is read by the helper, not named here.
text = open(models_path).read()
check(text.count('apiKey') == 1, 'apiKey appears {} times in the models declaration'.format(text.count('apiKey')))
check('synthetic_api_key' not in text, 'the models declaration names the key file')
for forbidden in ('authHeader', 'headers'):
    check(forbidden not in text, 'the models declaration sets {}'.format(forbidden))

upserts = models.get('upsertPaths', [])
check(all(entry['path'] == ['providers', 'synthetic', 'models'] and entry['key'] == 'id' for entry in upserts), 'an upsert is not keyed by id under providers.synthetic.models')
declared = {entry['value']['id']: entry['value'] for entry in upserts}
check(len(declared) == len(upserts), 'two upserts name the same model')
check(sorted(declared) == sorted(LEVEL_MAPS), 'declared models are {}, expected {}'.format(sorted(declared), sorted(LEVEL_MAPS)))

for model_id, value in declared.items():
    remote = snapshot.get(model_id)
    if remote is None:
        failures.append('the snapshot has no entry for {}'.format(model_id))
        continue
    check(value.get('thinkingLevelMap') == LEVEL_MAPS.get(model_id), '{} thinkingLevelMap is {}'.format(model_id, value.get('thinkingLevelMap')))
    # The levels the map sends must be exactly the efforts the snapshot lists.
    sent = sorted({send for send in LEVEL_MAPS.get(model_id, {}).values() if send not in (None, 'none')})
    listed = sorted(effort for effort in remote['reasoning_parameters']['efforts'] if effort != 'none')
    check(sent == listed, '{}: the expected map sends {} but the snapshot lists {}'.format(model_id, sent, listed))
    check(value.get('reasoning') is True, '{} is not marked reasoning'.format(model_id))
    check(value.get('name') == remote['display_name'], '{} name is {!r}'.format(model_id, value.get('name')))
    check(value.get('contextWindow') == remote['context_length'], '{} contextWindow is {!r}'.format(model_id, value.get('contextWindow')))
    check(value.get('maxTokens') == remote['max_output_length'], '{} maxTokens is {!r}'.format(model_id, value.get('maxTokens')))
    check(value.get('input') == remote['input_modalities'], '{} input is {!r}'.format(model_id, value.get('input')))
    prices = {
        'input': 'prompt',
        'output': 'completion',
        'cacheRead': 'input_cache_reads',
        'cacheWrite': 'input_cache_writes',
    }
    cost = value.get('cost', {})
    check(sorted(cost) == sorted(prices), '{} cost fields are {}'.format(model_id, sorted(cost)))
    for field, source in prices.items():
        per_token = float(remote['pricing'][source].lstrip('$'))
        got = cost.get(field)
        check(
            isinstance(got, (int, float)) and math.isclose(got, per_token * 1000000, rel_tol=1e-9, abs_tol=1e-12),
            '{} cost.{} is {!r}, expected {} per million'.format(model_id, field, got, per_token * 1000000),
        )

check('xhigh' not in declared.get(GLM, {}).get('thinkingLevelMap', {}), 'GLM 5.3 carries an xhigh key')

# --- settings.json declaration ----------------------------------------------

check(
    settings.get('set') == {'defaultProvider': 'synthetic', 'defaultModel': GLM, 'defaultProjectTrust': 'never'},
    'settings set is {}'.format(settings.get('set')),
)
levels = {tuple(entry['path']): entry['value'] for entry in settings.get('setPaths', [])}
expected_levels = {('modelThinkingLevels', 'synthetic/' + model_id): effort for model_id, effort in STARTUP.items()}
check(levels == expected_levels, 'modelThinkingLevels leaves are {}, expected {}'.format(levels, expected_levels))
check(set(settings) == {'set', 'setPaths'}, 'the settings declaration carries fields besides set and setPaths')

# --- merging ----------------------------------------------------------------


def merge(target, declared_path, label):
    result = subprocess.run(
        [merger, '--label', label, '--settings', target, '--declared', declared_path],
        env={}, capture_output=True, text=True,
    )
    check(result.returncode == 0, 'the {} merger refused {}: {}'.format(label, target, result.stderr.strip()))


def mode(path):
    return stat.S_IMODE(os.stat(path).st_mode)


os.makedirs(workdir, exist_ok=True)

# AE4: a model and a provider the user added by hand survive, twice over.
hand_added = {'id': 'hf:example/Hand-Added', 'name': 'Hand added', 'contextWindow': 1000}
stale_glm = {'id': GLM, 'name': 'user edit', 'reasoning': False, 'maxTokens': 1}
other_provider = {
    'baseUrl': 'http://localhost:11434/v1',
    'api': 'openai-completions',
    'apiKey': 'ollama',
    'models': [{'id': 'llama3'}],
}
seeded_models = os.path.join(workdir, 'models.json')
with open(seeded_models, 'w') as handle:
    json.dump({
        'providers': {
            'ollama': other_provider,
            'synthetic': {'compat': {'supportsStore': False}, 'models': [hand_added, stale_glm]},
        },
    }, handle)
os.chmod(seeded_models, 0o644)

merge(seeded_models, models_path, 'Pi models')
first = load(seeded_models)
merge(seeded_models, models_path, 'Pi models')
second = load(seeded_models)
check(first == second, 'merging the models declaration twice changed the file')
check(mode(seeded_models) == 0o600, 'merged models.json is mode {:o}'.format(mode(seeded_models)))
check(first['providers'].get('ollama') == other_provider, 'the second provider did not survive the merge')
synthetic = first['providers'].get('synthetic', {})
check(synthetic.get('compat') == {'supportsStore': False}, 'a user key beside the declared provider scalars was lost')
by_id = {entry['id']: entry for entry in synthetic.get('models', [])}
check(by_id.get(hand_added['id']) == hand_added, 'the hand-added model did not survive the merge')
check(len(synthetic.get('models', [])) == len(by_id), 'the merge left a duplicate model entry')
check(sorted(by_id) == sorted([hand_added['id']] + list(LEVEL_MAPS)), 'merged model ids are {}'.format(sorted(by_id)))
check(by_id.get(GLM) == declared.get(GLM), 'the stale GLM entry was not replaced by the declared one')
check(synthetic.get('apiKey') == '!' + helper and synthetic.get('api') == 'openai-completions', 'the merged provider scalars are wrong')

created_models = os.path.join(workdir, 'created-models.json')
merge(created_models, models_path, 'Pi models')
created = load(created_models) if os.path.exists(created_models) else {}
check(
    sorted(entry['id'] for entry in created.get('providers', {}).get('synthetic', {}).get('models', [])) == sorted(LEVEL_MAPS),
    'merging into a missing models.json did not create every model',
)
check(os.path.exists(created_models) and mode(created_models) == 0o600, 'a created models.json is not mode 0600')

seeded_settings = os.path.join(workdir, 'settings.json')
with open(seeded_settings, 'w') as handle:
    json.dump({
        'theme': 'dark',
        'defaultProjectTrust': 'always',
        'lastChangelogVersion': '1.0.0',
        'modelThinkingLevels': {'synthetic/hf:example/Hand-Added': 'low', 'synthetic/' + GLM: 'low'},
    }, handle)
os.chmod(seeded_settings, 0o644)
merge(seeded_settings, settings_path, 'Pi settings')
merged_settings = load(seeded_settings)
check(
    merged_settings == {
        'theme': 'dark',
        'defaultProvider': 'synthetic',
        'defaultModel': GLM,
        'defaultProjectTrust': 'never',
        'lastChangelogVersion': '1.0.0',
        'modelThinkingLevels': dict(
            {'synthetic/hf:example/Hand-Added': 'low'},
            **{'synthetic/' + model_id: effort for model_id, effort in STARTUP.items()},
        ),
    },
    'merged settings.json is {}'.format(merged_settings),
)
check(mode(seeded_settings) == 0o600, 'merged settings.json is mode {:o}'.format(mode(seeded_settings)))

for message in failures:
    print(message)
sys.exit(1 if failures else 0)
