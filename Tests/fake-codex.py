#!/usr/bin/env python3
"""模拟分段额度响应、更新事件和连接断开。"""
import json
import sys
import time

def emit(message):
    line = json.dumps(message) + '\n'
    sys.stdout.write(line[:9]); sys.stdout.flush()
    time.sleep(0.02)
    sys.stdout.write(line[9:]); sys.stdout.flush()

def limits(used):
    return {'rateLimitResetCredits': {'availableCount': 2, 'credits': [
        {'status': 'available', 'expiresAt': 2000000000},
        {'status': 'available', 'expiresAt': 2000000100}]}, 'rateLimitsByLimitId': {'codex': {
        'planType': 'plus',
        'primary': {'usedPercent': used, 'windowDurationMins': 300, 'resetsAt': 2000000000},
        'secondary': {'usedPercent': 76, 'windowDurationMins': 10080, 'resetsAt': 2000000000}}}}

initialized = False
quota_reads = 0
for line in sys.stdin:
    message = json.loads(line)
    method = message['method']
    if method == 'initialize':
        assert method == 'initialize'
        emit({'id': message['id'], 'result': {}})
    elif method == 'initialized':
        initialized = True
    elif method == 'account/rateLimits/read':
        assert initialized
        quota_reads += 1
        if quota_reads == 1:
            emit({'id': message['id'], 'result': limits(80)})
        else:
            emit({'id': message['id'], 'result': limits(75)})
            emit({'method': 'account/rateLimits/updated', 'params': limits(74)})
            time.sleep(0.2)
            sys.exit(0)
    else:
        raise AssertionError(f'unexpected method: {method}')
