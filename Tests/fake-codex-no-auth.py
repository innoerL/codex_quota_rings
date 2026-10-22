#!/usr/bin/env python3
"""Protocol fixture: Codex app-server is installed but the user is signed out."""
import json
import sys

for line in sys.stdin:
    message = json.loads(line)
    if message.get('method') == 'initialize':
        response = {
            'id': message['id'],
            'error': {'code': -32001, 'message': 'Authentication required: please sign in to Codex'},
        }
        sys.stdout.write(json.dumps(response) + '\n')
        sys.stdout.flush()
        break
