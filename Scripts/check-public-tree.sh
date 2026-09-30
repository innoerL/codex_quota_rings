#!/bin/zsh
set -euo pipefail
quota_repo="${1:-${0:A:h:h}}"
while IFS= read -r -d '' file; do
    case "$file" in
        build/*|outputs/*|work/*|.superpowers/*|*.app/*|*.dSYM/*|*/.DS_Store|.DS_Store|*.o|*.swiftmodule|*.swiftdoc|*.swiftsourceinfo|*module-cache/*|auth.json|*/auth.json|.env|.env.*)
            print -u2 "FAIL: local/private artifact is tracked: $file"; exit 1 ;;
    esac
done < <(git -C "$quota_repo" ls-files -z)
print 'PASS: public source boundary'
