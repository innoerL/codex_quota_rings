#!/usr/bin/env python3
"""Protocol fixture: fragmented JSON, two polls, one push update, disconnect."""
import json
import sys
import time

def emit(message):
    line = json.dumps(message) + '\n'
    sys.stdout.write(line[:9]); sys.stdout.flush()
    time.sleep(0.02)
    sys.stdout.write(line[9:]); sys.stdout.flush()

def limits(used):
    return {'rateLimitsByLimitId': {'codex': {
        'primary': {'usedPercent': used, 'windowDurationMins': 300, 'resetsAt': 2000000000},
        'secondary': {'usedPercent': 76, 'windowDurationMins': 10080, 'resetsAt': 2000000000}}}}

stage = 0
for line in sys.stdin:
    message = json.loads(line)
    method = message['method']
    if stage == 0:
        assert method == 'initialize'
        emit({'id': message['id'], 'result': {}}); stage += 1
    elif stage == 1:
        assert method == 'initialized'; stage += 1
    elif stage == 2:
        assert method == 'account/rateLimits/read'
        emit({'id': message['id'], 'result': limits(80)}); stage += 1
    elif stage == 3:
        assert method == 'account/rateLimits/read'
        emit({'id': message['id'], 'result': limits(75)})
        emit({'method': 'account/rateLimits/updated', 'params': limits(74)})
        time.sleep(0.2)
        sys.exit(0)
