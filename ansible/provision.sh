#!/bin/bash

set -o xtrace

virtualenv ./elastica-venv
source ./elastica-venv/bin/activate
pip install ansible==1.9.2

run_playbook() {
    # Write to stdout directly
    export PYTHONUNBUFFERED=1

    # No cows >_<
    export ANSIBLE_NOCOWS=1

    # Root of git repo
    if [ -z "$ES_PROJECT_ROOT" ]; then
        export ES_PROJECT_ROOT="$(dirname $(dirname $(readlink -f $0)))"
    fi

    ./elastica-venv/bin/ansible ./playbook.yml -i ./inventory.txt -v | tee ./progress.log

    if grep -q "FATAL\|ERROR" ./progress.log; then
        return 1
    fi
}

check_cluster() {
    curl -m 5 -s -o /dev/null "http://localhost:9200" &&
    curl -m 5 -s -o /dev/null "http://localhost:9201"
    return $?
}

travis_retry() {
    # We don't use builtin Travis CI function, because this script is also used for vagrant provision.
    # But main idea of restarts is so simple, so lets override it without name change.

    $@ && return 0

    echo "The command $@ failed. Retrying, 2 of 3"
    sleep 60s && $@ && return 0

    echo "The command $@ failed. Retrying, 3 of 3"
    sleep 60s && $@ && return 0

    echo "The command $@ failed."
    return 1
}

travis_retry run_playbook || exit 1

travis_retry check_cluster || exit 1
