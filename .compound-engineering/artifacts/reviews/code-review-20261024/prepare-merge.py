import json,re
from pathlib import Path
r=Path(__file__).parent
raw=json.loads((r/'raw-returns.json').read_text())
def key(f): return (f['file'].strip(),str(f['line']),' '.join(f['title'].lower().split()))
details={}
for ret in raw:
 a=json.loads((r/(ret['reviewer']+'.json')).read_text())
 for f in a['findings']: details[(ret['reviewer'],*key(f))]=f
 for f in ret['findings']: f['evidence']=details[(ret['reviewer'],*key(f))]['evidence']
peer=json.loads((r/'adversarial-claude.json').read_text())
# The required temporary venue is intentional, not a defect.
rejected=[{'claim':peer['findings'][1]['title'],'reason':'Plan Linux mutation evidence venue lines 340-349 explicitly requires temporary PR workflow execution followed by removal after evidence; initial publication is allowed. Exact anchors intentionally fail closed when evidence no longer applies.'}]
peer['findings']=peer['findings'][:1]
for f in peer['findings']: details[(peer['reviewer'],*key(f))]=f
raw.append(peer)
f=dict(title='Restore the independent no-embedded-credentials activation contract',severity='P2',file='tests/podman-containers.nix',line=239,confidence=100,autofix_class='gated_auto',owner='downstream-resolver',requires_verification=True,pre_existing=False,suggested_fix='Retain the new effect probes and restore an independent credential-free activation-artifact assertion over the actual block, with a fake embedded-token negative control; avoid matching incidental store-path hashes.',first_evidence='tests/podman-containers.nix:239 --       if ! python3 ${authEffects} ${authBlock}; then',why_it_matters='The diff deletes the independent check forbidding embedded auths/token/password data in the world-readable activation artifact. The replacement only checks the created auth.json and preserved target bytes, so a credential embedded elsewhere in the block is no longer rejected. R4 requires retaining independent security contracts.',evidence=['git diff 09e9f5aaf56f3bb549c69bc8499de9c208737e4d -- tests/podman-containers.nix removes the activationScriptData no-embedded-token assertion.', 'tests/podman-containers.nix:24-60 inspects fresh auth.json, dry-run state, modes and existing bytes, without inspecting embedded credentials in the activation block.','Plan R4 retains every named independent contract.'])
raw.append({'reviewer':'synthesis','findings':[f]})
details[('synthesis',*key(f))]=f
(r/'raw-returns-original.json').write_text((r/'raw-returns.json').read_text())
(r/'raw-returns.json').write_text(json.dumps(raw,indent=2)+'\n')
(r/'source-detail-map.json').write_text(json.dumps([dict(reviewer=k[0],fingerprint=list(k[1:]),detail=v) for k,v in details.items()],indent=2)+'\n')
(r/'merge-decisions.json').write_text(json.dumps({'rejected_claims':rejected},indent=2)+'\n')
